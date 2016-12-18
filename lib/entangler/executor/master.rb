require_relative 'background/master'

module Entangler
  module Executor
    class Master < Base
      include Entangler::Executor::Background::Master

      def run
        perform_initial_rsync
        sleep 1
        start_remote_slave
        super
        @remote_writer.close
        @remote_reader.close
      end

      private

      def validate_opts
        super
        if @opts[:remote_mode]
          raise 'Missing remote base dir' unless @opts.keys.include?(:remote_base_dir)
          raise 'Missing remote user' unless @opts.keys.include?(:remote_user)
          raise 'Missing remote host' unless @opts.keys.include?(:remote_host)
          @opts[:remote_port] ||= '22'
          res = `#{generate_ssh_command("[[ -d '#{@opts[:remote_base_dir]}' ]] && echo 'ok' || echo 'missing'")}`
          raise 'Cannot connect to remote' if res.empty?
          raise 'Remote base dir invalid' unless res.strip == 'ok'
        else
          @opts[:remote_base_dir] = File.realpath(File.expand_path(@opts[:remote_base_dir]))
          raise "Destination directory can't be the same as the base directory" if @opts[:remote_base_dir] == base_dir
          raise "Destination directory doesn't exist" unless Dir.exist?(@opts[:remote_base_dir])
        end
      end

      def perform_initial_rsync
        logger.info 'Running initial sync'
        local_folders = `find #{base_dir} -type d`.split("\n").tap { |a| a.shift(1) }.map { |path| path.sub(base_dir, '') }

        remote_find_cmd = "find #{@opts[:remote_base_dir]} -type d"
        raw_remote_folders = `#{@opts[:remote_mode] ? generate_ssh_command(remote_find_cmd) : remote_find_cmd}`
        remote_folders = raw_remote_folders.split("\n").tap { |a| a.shift(1) }.map { |path| path.sub(@opts[:remote_base_dir], '') }

        all_folders = remote_folders | local_folders
        ignore_matches = all_folders.map { |path| @opts[:ignore].map { |regexp| (regexp.match(path) || [])[0] }.compact.first }.compact.uniq
        exclude_folders = ignore_matches.map { |path| path[1..-1] }
        exclude_args = exclude_folders.map { |path| "--exclude #{path}" }.join(' ')

        ssh_settings = @opts[:remote_mode] ? "-e \"ssh -p #{@opts[:remote_port]}\"" : ''
        remote_path = @opts[:remote_mode] ? "#{@opts[:remote_user]}@#{@opts[:remote_host]}:#{@opts[:remote_base_dir]}/" : "#{@opts[:remote_base_dir]}/"

        rsync_cmd = "rsync -azv #{exclude_args} #{ssh_settings} --delete #{base_dir}/ #{remote_path}"

        IO.popen(rsync_cmd).each do |line|
          logger.debug line.chomp
        end
        logger.debug 'Initial sync complete'
      end

      def generate_ssh_command(cmd)
        "ssh -q #{@opts[:remote_user]}@#{@opts[:remote_host]} -p #{@opts[:remote_port]} -C \"#{cmd}\""
      end
    end
  end
end
