module Entangler
  module Executor
    class Master < Base
      def validate_opts
        super
        raise 'Missing remote base dir' unless @opts.keys.include?(:remote_base_dir)
        raise 'Missing remote user' unless @opts.keys.include?(:remote_user)
        raise 'Missing remote host' unless @opts.keys.include?(:remote_host)
        @opts[:remote_port] ||= '22'
        res = `ssh -q #{@opts[:remote_user]}@#{@opts[:remote_host]} -p #{@opts[:remote_port]} -C "[[ -d '#{@opts[:remote_base_dir]}' ]] && echo 'ok' || echo 'missing'"`
        raise 'Cannot connect to remote' if res.empty?
        raise 'Remote base dir invalid' unless res.strip == 'ok'
      end

      def run
        perform_initial_rsync
        sleep 1
        start_remote_slave
        super
        Process.wait @remote_thread[:pid] rescue nil
        @remote_writer.close
        @remote_reader.close
      end

      def kill_off_threads
        Process.kill("INT", @remote_thread[:pid])
        super
      end

      def perform_initial_rsync
        logger.info 'Running initial sync'
        IO.popen("rsync -azv --exclude .git --exclude log --exclude .entangler --exclude tmp -e \"ssh -p #{@opts[:remote_port]}\" --delete #{base_dir}/ #{@opts[:remote_user]}@#{@opts[:remote_host]}:#{@opts[:remote_base_dir]}/").each do |line|
          logger.debug line.chomp
        end
        logger.debug 'Initial sync complete'
      end

      def start_remote_slave
        require 'open3'
        @remote_writer, @remote_reader, remote_err, @remote_thread = Open3.popen3("ssh -q #{@opts[:remote_user]}@#{@opts[:remote_host]} -p #{@opts[:remote_port]} -C \"source ~/.rvm/environments/default && entangler slave #{@opts[:remote_base_dir]}\"")
        remote_err.close
      end
    end
  end
end
