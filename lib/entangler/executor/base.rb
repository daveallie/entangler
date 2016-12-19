require 'logger'
require 'fileutils'
require 'thread'
require_relative 'background/base'

module Entangler
  module Executor
    class Base
      include Entangler::Executor::Background::Base

      attr_reader :base_dir

      def initialize(base_dir, opts = {})
        @base_dir = File.realpath(File.expand_path(base_dir))
        @last_changed_at = 0
        @changed_files = []
        @listener_pauses = [false, false]
        @opts = opts
        @opts[:ignore] = [%r{^\.git.*}] unless @opts.key?(:ignore)
        @opts[:ignore] << %r{^\.entangler.*}

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
        start_listener
        start_remote_io
        Signal.trap('INT') { kill_off_threads }
        wait_for_threads
      ensure
        stop_listener
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
