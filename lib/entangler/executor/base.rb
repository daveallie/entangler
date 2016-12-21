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
        validate_base_dir(base_dir)
        @base_dir = File.realpath(File.expand_path(base_dir))
        @recently_received_paths = []
        @listener_pauses = [false, false]
        @opts = opts
        @opts[:ignore] = [%r{^\.git(?:/[^/]+)*$}] unless @opts.key?(:ignore)
        @opts[:ignore] << /^\.entangler.*/

        validate_opts
      end

      def generate_abs_path(rel_path)
        File.join(base_dir, rel_path)
      end

      def strip_base_path(path, base_dir = self.base_dir)
        File.expand_path(path).sub(base_dir, '')
      end

      def run
        logger.info("Entangler v#{Entangler::VERSION}")
        start_listener
        start_remote_io
        Signal.trap('INT') { kill_off_threads }
        wait_for_threads
      ensure
        stop_listener
        logger.info('Stopping Entangler')
      end

      protected

      def validate_opts; end

      def send_to_remote(msg = {})
        Marshal.dump(msg, @remote_writer)
      end

      def logger
        FileUtils.mkdir_p log_dir
        @logger ||= begin
          l = Logger.new(File.join(log_dir, 'entangler.log'))
          l.level = @opts[:verbose] ? Logger::DEBUG : Logger::INFO
          l
        end
      end

      def log_dir
        File.join(base_dir, '.entangler', 'log')
      end

      def validate_base_dir(base_dir)
        raise Entangler::ValidationError, "Base directory doesn't exist" unless File.exist?(base_dir)
        raise Entangler::ValidationError, 'Base directory is a file' unless File.directory?(base_dir)
      end
    end
  end
end
