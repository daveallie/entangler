require_relative 'entangler/version'
require_relative 'entangler/errors'
require_relative 'entangler/entangled_file'

module Entangler
  class << self
    attr_accessor :executor

    def run(base_dir, opts = {})
      opts = { mode: 'master', remote_mode: true }.merge(opts)

      require 'entangler/executor/base'
      if opts[:mode] == 'master'
        require 'entangler/executor/master'
        self.executor = Entangler::Executor::Master.new(base_dir, opts)
      elsif opts[:mode] == 'slave'
        require 'entangler/executor/slave'
        self.executor = Entangler::Executor::Slave.new(base_dir, opts)
      end

      executor.run
    end
  end
end
