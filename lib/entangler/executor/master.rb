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
          @opts[:remote_port] ||= '22'
          validate_remote_opts
        else
          validate_local_opts
        end
      end

      def validate_local_opts
        unless File.exist?(@opts[:remote_base_dir])
          raise Entangler::ValidationError, "Destination directory doesn't exist"
        end
        unless File.directory?(@opts[:remote_base_dir])
          raise Entangler::ValidationError, 'Destination directory is a file'
        end
        @opts[:remote_base_dir] = File.realpath(File.expand_path(@opts[:remote_base_dir]))
        return unless @opts[:remote_base_dir] == base_dir
        raise Entangler::ValidationError, "Destination directory can't be the same as the base directory"
      end

      def validate_remote_opts
        keys = @opts.keys
        raise Entangler::ValidationError, 'Missing remote base dir' unless keys.include?(:remote_base_dir)
        raise Entangler::ValidationError, 'Missing remote user' unless keys.include?(:remote_user)
        raise Entangler::ValidationError, 'Missing remote host' unless keys.include?(:remote_host)
        validate_remote_base_dir
        validate_remote_entangler_version
      end

      def validate_remote_base_dir
        res = `#{generate_ssh_command("[[ -d '#{@opts[:remote_base_dir]}' ]] && echo 'ok' || echo 'missing'")}`
        raise Entangler::ValidationError, 'Cannot connect to remote' if res.empty?
        raise Entangler::ValidationError, 'Remote base dir invalid' unless res.strip == 'ok'
      end

      def validate_remote_entangler_version
        return unless @opts[:remote_mode]
        res = `#{generate_ssh_command('source ~/.rvm/environments/default && entangler --version')}`
        remote_version = Gem::Version.new(res.strip)
        local_version = Gem::Version.new(Entangler::VERSION)
        return unless major_version_mismatch?(local_version, remote_version)
        msg = 'Entangler version too far apart, please update either local or remote Entangler.' \
              " Local version is #{local_version} and remote version is #{remote_version}."
        raise Entangler::VersionMismatchError, msg
      end

      def major_version_mismatch?(version1, version2)
        version1.segments[0] != version2.segments[0] ||
          (version1.segments[0].zero? && version1 != version2) ||
          ((version1.prerelease? || version2.prerelease?) && version1 != version2)
      end

      def perform_initial_rsync
        logger.info 'Running initial sync'
        IO.popen(rsync_cmd_string).each do |line|
          logger.debug line.chomp
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

      def rsync_cmd_string
        exclude_args = find_rsync_ignore_folders.map { |path| "--exclude #{path}" }.join(' ')
        remote_path = @opts[:remote_mode] ? "#{@opts[:remote_user]}@#{@opts[:remote_host]}:" : ''
        remote_path += "#{@opts[:remote_base_dir]}/"

        cmd = "rsync -azv #{exclude_args}"
        cmd += " -e \"ssh -p #{@opts[:remote_port]}\"" if @opts[:remote_mode]
        cmd + " --delete #{base_dir}/ #{remote_path}"
      end
    end
  end
end
