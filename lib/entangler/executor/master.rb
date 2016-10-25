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
        raise 'Missing remote base dir' unless @opts.keys.include?(:remote_base_dir)
        raise 'Missing remote user' unless @opts.keys.include?(:remote_user)
        raise 'Missing remote host' unless @opts.keys.include?(:remote_host)
        @opts[:remote_port] ||= '22'
        res = `ssh -q #{@opts[:remote_user]}@#{@opts[:remote_host]} -p #{@opts[:remote_port]} -C "[[ -d '#{@opts[:remote_base_dir]}' ]] && echo 'ok' || echo 'missing'"`
        raise 'Cannot connect to remote' if res.empty?
        raise 'Remote base dir invalid' unless res.strip == 'ok'
      end

      def perform_initial_rsync
        logger.info 'Running initial sync'
        IO.popen("rsync -azv --exclude .git --exclude log --exclude .entangler --exclude tmp -e \"ssh -p #{@opts[:remote_port]}\" --delete #{base_dir}/ #{@opts[:remote_user]}@#{@opts[:remote_host]}:#{@opts[:remote_base_dir]}/").each do |line|
          logger.debug line.chomp
        end
        logger.debug 'Initial sync complete'
      end
    end
  end
end
