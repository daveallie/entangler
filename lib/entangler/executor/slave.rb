# frozen_string_literal: true

module Entangler
  module Executor
    class Slave < Base
      def initialize(base_dir, opts = {})
        super(base_dir, opts)
        $stdin.binmode
        $stdout.binmode
        $stdin.sync = true
        $stdout.sync = true

        @remote_reader = $stdin
        @remote_writer = $stdout
        $stderr.reopen(File.join(Entangler::Logger.log_file_path(base_dir, 'entangler.err')), 'w')
      end
    end
  end
end
