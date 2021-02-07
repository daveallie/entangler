# frozen_string_literal: true

require 'logger'
require 'fileutils'
require_relative 'background/base'
require_relative 'validation/base'

module Entangler
  module Executor
    class Base
      include Entangler::Executor::Background::Base
      include Entangler::Executor::Validation::Base

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
        Entangler::Logger.create_log_dir(base_dir)
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
        logger.info('Ready!')
        wait_for_threads
      ensure
        stop_listener
        logger.info('Stopping Entangler')
      end

      protected

      def send_to_remote(msg = {})
        Marshal.dump(msg, @remote_writer)
      end

      def logger
        @logger ||= Entangler::Logger.new(log_outputs, verbose: @opts[:verbose])
      end

      def log_outputs
        [Entangler::Logger.log_file_path(base_dir)]
      end
    end
  end
end
