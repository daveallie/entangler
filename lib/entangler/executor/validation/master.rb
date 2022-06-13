# frozen_string_literal: true

module Entangler
  module Executor
    module Validation
      module Master
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
          if res.empty?
            msg = 'Entangler is not installed on the remote server.' \
                  ' Install Entangler on the remote server (SSH in, then `gem install entangler`), then try again.'
            raise Entangler::NotInstalledOnRemoteError, msg
          end

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
      end
    end
  end
end
