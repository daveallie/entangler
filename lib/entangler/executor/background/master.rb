# frozen_string_literal: true

require 'open3'

module Entangler
  module Executor
    module Background
      module Master
        protected

        def start_remote_slave
          logger.info('Starting - Entangler on remote')
          ignore_opts = @opts[:ignore].map { |regexp| "-i '#{regexp.inspect}'" }.join(' ')
          entangler_cmd = +"entangler slave #{@opts[:remote_base_dir]} #{ignore_opts}"
          entangler_cmd << " --verbose" if @opts[:verbose]
          ssh_cmd = generate_ssh_command(entangler_cmd, source_rvm: true)
          full_cmd = @opts[:remote_mode] ? ssh_cmd : entangler_cmd

          @remote_writer, @remote_reader, remote_err, @remote_thread = Open3.popen3(full_cmd)
          remote_err.close
        end

        def wait_for_threads
          super
          begin
            Process.wait @remote_thread[:pid]
          rescue StandardError
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
