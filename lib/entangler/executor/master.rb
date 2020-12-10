# frozen_string_literal: true

require_relative 'helpers'
require_relative 'background/master'
require_relative 'validation/master'

module Entangler
  module Executor
    class Master < Base
      include Entangler::Executor::Background::Master
      include Entangler::Executor::Validation::Master

      def run
        perform_initial_rsync
        sleep 1
        start_remote_slave
        super
        @remote_writer.close
        @remote_reader.close
      end

      private

      def log_outputs
        outs = [Entangler::Logger.log_file_path(base_dir)]
        outs << $stdout unless @opts[:quiet]
      end

      def perform_initial_rsync
        logger.info 'Running initial sync'
        with_temp_rsync_ignores do |file_path|
          IO.popen(rsync_cmd_string(file_path)).each do |line|
            logger.debug line.chomp
          end
        end
        logger.debug 'Initial sync complete'
      end

      def find_all_folders
        local_folders = process_raw_file_list(`find #{base_dir} -type d`, base_dir)

        remote_find_cmd = "find #{@opts[:remote_base_dir]} -type d"
        raw_remote_folders = `#{@opts[:remote_mode] ? generate_ssh_command(remote_find_cmd) : remote_find_cmd}`
        remote_folders = process_raw_file_list(raw_remote_folders, @opts[:remote_base_dir])

        remote_folders | local_folders
      end

      def process_raw_file_list(output, base)
        output.split("\n").tap { |a| a.shift(1) }
              .map { |path| path.sub("#{base}/", '') }
      end

      def find_rsync_ignore_folders
        find_all_folders.map do |path|
          @opts[:ignore].map { |regexp| (regexp.match(path) || [])[0] }.compact.first
        end.compact.uniq
      end

      def generate_ssh_command(cmd)
        "ssh -q #{remote_hostname} -p #{@opts[:remote_port]} -C \"#{cmd}\""
      end

      def remote_hostname
        "#{@opts[:remote_user]}@#{@opts[:remote_host]}"
      end

      def with_temp_rsync_ignores
        Entangler::Helper.with_temp_file(name: 'rsync_ignores', contents: find_rsync_ignore_folders.join("\n")) do |f|
          yield f.path
        end
      end

      def rsync_cmd_string(rsync_ignores_file_path)
        remote_path = @opts[:remote_mode] ? "#{@opts[:remote_user]}@#{@opts[:remote_host]}:" : ''
        remote_path += "#{@opts[:remote_base_dir]}/"

        cmd = "rsync -azv --exclude-from #{rsync_ignores_file_path}"
        cmd += " -e \"ssh -p #{@opts[:remote_port]}\"" if @opts[:remote_mode]
        cmd + " --delete #{base_dir}/ #{remote_path}"
      end
    end
  end
end
