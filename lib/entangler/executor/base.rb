require 'logger'
require 'fileutils'
require 'thread'

module Entangler
  module Executor
    class Base
      attr_reader :base_dir

      def initialize(base_dir, opts = {})
        @base_dir = File.realpath(File.expand_path(base_dir))
        @notify_sleep = 0
        @opts = opts
        @opts[:ignore] = [/^\/\.git.*/, /^\/\.entangler.*/, /^\/\.idea.*/, /^\/log.*/, /^\/tmp.*/] unless @opts.has_key?(:ignore)
        validate_opts
        logger.info("Starting executor")
      end

      def validate_opts
        raise "Base directory doesn't exist" unless Dir.exists?(self.base_dir)
      end

      def run
        start_notify_daemon
        start_local_io
        start_remote_io
        start_local_consumer
        logger.debug("NOTIFY PID: #{@notify_daemon_pid}")
        Signal.trap("INT") { kill_off_threads }
        @consumer_thread.join
        @remote_io_thread.join
        @local_io_thread.join
        Process.wait @notify_daemon_pid
      end

      def kill_off_threads
        Process.kill("TERM", @notify_daemon_pid) rescue nil
        @consumer_thread.terminate
        @remote_io_thread.terminate
        @local_io_thread.terminate
      end

      def start_file_transfers(paths, pipe)
        Marshal.dump(paths.map{|path| EntangledFile.new(path) }, pipe)
      end

      def start_notify_daemon
        logger.info('starting notify daemon')
        r,w = IO.pipe
        @notify_daemon_pid = spawn(start_notify_daemon_cmd, out: w)
        w.close
        @notify_reader = r
      end

      def start_local_io
        logger.info('starting local IO')
        @local_action_queue = Queue.new
        @local_io_thread = Thread.new do
          begin
            msg = []
            loop do
              ready = IO.select([@notify_reader]).first
              next unless ready && ready.any?
              break if ready.first.eof?
              line = ready.first.gets
              next if line.nil? || line.empty?
              line = line.strip
              next if line == '-'
              @local_action_queue.push line
            end
          rescue => e
            $stderr.puts e.message
            $stderr.puts e.backtrace.join("\n")
            kill_off_threads
          end
        end
      end

      def start_local_consumer
        @consumer_thread = Thread.new do
          loop do
            msg = [@local_action_queue.pop]
            while !@local_action_queue.empty?
              msg << @local_action_queue.pop
            end
            while Time.now.to_f <= @notify_sleep
              sleep 0.5
              while !@local_action_queue.empty?
                msg << @local_action_queue.pop
              end
            end
            process_lines(msg.uniq)
            msg = []
            sleep 0.5
          end
        end
      end

      def send_to_remote(msg = {})
        Marshal.dump(msg, @remote_writer)
      end

      def start_remote_io
        logger.info('starting remote IO')
        @remote_io_thread = Thread.new do
          begin
            loop do
              msg = Marshal.load(@remote_reader)
              next if msg.nil?

              case msg[:type]
              when :new_changes
                logger.debug("Got #{msg[:content].length} new folder changes from remote")

                created_dirs = []
                dirs_to_remove = []
                files_to_remove = []
                files_to_update = []

                msg[:content].each do |base, changes|
                  possible_creation_dirs = changes[:dirs].clone
                  possible_creation_files = changes[:files].keys.clone
                  full_base_path = generate_abs_path(base)

                  unless File.directory?(full_base_path)
                    FileUtils::mkdir_p(full_base_path)
                    @notify_sleep = Time.now.to_i + 60
                  end

                  Dir.entries(full_base_path).each do |f|
                    next if ['.', '..'].include? f
                    full_path = File.join(generate_abs_path(base), f)
                    if File.directory?(full_path)
                      possible_creation_dirs -= [f]
                      dirs_to_remove << full_path unless changes[:dirs].include?(f)
                    elsif changes[:files].has_key?(f)
                      possible_creation_files -= [f]
                      files_to_update << File.join(base, f) unless changes[:files][f] == [File.size(full_path), File.mtime(full_path).to_i]
                    else
                      files_to_remove << full_path
                    end
                  end

                  dirs_to_create = possible_creation_dirs.map{|d| File.join(generate_abs_path(base), d)}
                  if dirs_to_create.any?
                    logger.debug("Creating #{dirs_to_create.length} dirs")
                    @notify_sleep = Time.now.to_i + 60
                    FileUtils.mkdir_p dirs_to_create
                  end
                  created_dirs += dirs_to_create
                  files_to_update += possible_creation_files.map{|f| File.join(base, f)}
                end

                @notify_sleep = Time.now.to_i + 60 if (files_to_remove + created_dirs + dirs_to_remove + files_to_update).any?

                if files_to_remove.any?
                  logger.debug("Deleting #{files_to_remove.length} files")
                  FileUtils.rm files_to_remove
                end
                if dirs_to_remove.any?
                  logger.debug("Deleting #{dirs_to_remove.length} dirs")
                  FileUtils.rm_r dirs_to_remove
                end
                if files_to_update.any?
                  logger.debug("Creating #{files_to_update.length} new entangled files to sync")
                  send_to_remote(type: :entangled_files, content: files_to_update.map{|f| Entangler::EntangledFile.new(f) })
                end
                @notify_sleep = Time.now.to_f + 0.5 if (files_to_remove + created_dirs + dirs_to_remove + files_to_update).any?
                @notify_sleep += 60 if files_to_update.any?
              when :entangled_files
                logger.debug("Got #{msg[:content].length} entangled files from remote")
                completed_files, updated_files = msg[:content].partition(&:done?)

                completed_files.each(&:export)

                updated_files = updated_files.find_all{|f| f.state != 1 || f.file_exists? }
                if updated_files.any?
                  send_to_remote(type: :entangled_files, content: updated_files)
                end
                @notify_sleep = Time.now.to_f + 0.5 if completed_files.any?
              end
            end
          rescue => e
            $stderr.puts e.message
            $stderr.puts e.backtrace.join("\n")
            kill_off_threads
          end
        end
      end

      def process_lines(lines)
        to_process = lines.map do |line|
          path = line[2..-1]
          stripped_path = strip_base_path(path)
          next unless @opts[:ignore].nil? || @opts[:ignore].none?{|i| stripped_path.match(i) }
          next unless File.directory?(path)

          [stripped_path, generate_file_list(path)]
        end.compact.sort_by(&:first)

        return unless to_process.any?
        logger.debug("PROCESSING #{to_process.count} folder/s")
        send_to_remote(type: :new_changes, content: to_process)
      end

      def generate_file_list(path)
        dirs = []
        files = {}

        Dir.entries(path).each do |f|
          next if ['.', '..'].include? f
          f_path = File.join(path, f)
          if File.directory? f_path
            dirs << f
          else
            files[f] = [File.size(f_path), File.mtime(f_path).to_i]
          end
        end

        {dirs: dirs, files: files}
      end

      def generate_abs_path(rel_path)
        File.join(self.base_dir, rel_path)
      end

      def strip_base_path(path, base_dir = self.base_dir)
        File.expand_path(path).sub(base_dir, '')
      end

      def start_notify_daemon_cmd
        uname = `uname`.strip.downcase
        raise 'Unsupported OS' unless ['darwin', 'linux'].include?(uname)

        "#{File.join(File.dirname(File.dirname(File.dirname(__FILE__))), 'notifier', 'bin', uname, 'notify')} #{self.base_dir}"
      end

      def logger
        FileUtils::mkdir_p log_dir
        @logger ||= Logger.new(File.join(log_dir, 'entangler.log'))
      end

      def log_dir
        File.join(base_dir, '.entangler', 'log')
      end
    end
  end
end
