module Entangler
  module Executor
    module Background
      module Master
        protected

        def start_remote_slave
          logger.info('Starting - Entangler on remote')
          require 'open3'
          ignore_opts = @opts[:ignore].map { |regexp| "-i '#{regexp.inspect}'" }.join(' ')
          entangler_cmd = "entangler slave #{@opts[:remote_base_dir]} #{ignore_opts}"
          ssh_cmd = generate_ssh_command("source ~/.rvm/environments/default && #{entangler_cmd}")
          full_cmd = @opts[:remote_mode] ? ssh_cmd : entangler_cmd

          @remote_writer, @remote_reader, remote_err, @remote_thread = Open3.popen3(full_cmd)
          remote_err.close
        end

        def wait_for_threads
          super
          begin
            Process.wait @remote_thread[:pid]
          rescue
            nil
          end
        end

        def kill_off_threads
          Process.kill('INT', @remote_thread[:pid])
          super
        end
      end
    end
  end
end
