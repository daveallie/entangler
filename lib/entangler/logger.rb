# frozen_string_literal: true

require 'fileutils'
require 'logger'

module Entangler
  class Logger
    def self.create_log_dir(base_dir)
      FileUtils.mkdir_p(File.dirname(log_file_path(base_dir)))
    end

    def self.log_file_path(base_dir, log_file_name = 'entangler.log')
      File.join(base_dir, '.entangler', 'log', log_file_name)
    end

    def initialize(outputs, verbose: false)
      @loggers = Array(outputs).map do |output|
        logger = ::Logger.new(output, 1, 10485760) # 10.megabytes.to_i

        logger.level = verbose ? ::Logger::DEBUG : ::Logger::INFO
        logger.formatter = proc do |severity, datetime, _, msg|
          date_format = datetime.strftime('%Y-%m-%d %H:%M:%S')
          "[#{date_format}] #{severity.rjust(5)}: #{msg}\n"
        end

        logger
      end
    end

    def level=(level)
      @loggers.each { |logger| logger.level = level }
    end

    ::Logger::Severity.constants.each do |level|
      define_method(level.downcase) do |*args|
        @loggers.each { |logger| logger.send(level.downcase, *args) }
      end
    end
  end
end
