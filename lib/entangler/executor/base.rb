require 'logger'
require 'fileutils'
require 'thread'
require_relative 'background/base'
require_relative 'processing/base'

module Entangler
  module Executor
    class Base
      include Entangler::Executor::Background::Base, Entangler::Executor::Processing::Base

      attr_reader :base_dir

      def initialize(base_dir, opts = {})
        @base_dir = File.realpath(File.expand_path(base_dir))
        @notify_sleep = 0
        @exported_at = 0
        @opts = opts
        @opts[:ignore] = [%r{^/\.git.*}] unless @opts.key?(:ignore)
        @opts[:ignore] << %r{^/\.entangler.*}

        validate_opts
        logger.info('Starting executor')
      end

      def generate_abs_path(rel_path)
        File.join(base_dir, rel_path)
      end

      def strip_base_path(path, base_dir = self.base_dir)
        File.expand_path(path).sub(base_dir, '')
      end

      def run
        start_notify_daemon
        start_local_io
        start_remote_io
        start_local_consumer
        logger.debug("NOTIFY PID: #{@notify_daemon_pid}")
        Signal.trap('INT') { kill_off_threads }
        wait_for_threads
      end

      protected

      def validate_opts
        raise "Base directory doesn't exist" unless Dir.exist?(base_dir)
      end

      def send_to_remote(msg = {})
        Marshal.dump(msg, @remote_writer)
      end

      def logger
        FileUtils.mkdir_p log_dir
        @logger ||= Logger.new(File.join(log_dir, 'entangler.log'))
      end

      def log_dir
        File.join(base_dir, '.entangler', 'log')
      end
    end
  end
end
