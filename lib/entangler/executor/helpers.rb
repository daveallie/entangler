# frozen_string_literal: true

module Entangler
  module Helper
    def self.with_temp_file(name: 'tmp_file', contents: nil)
      require 'tempfile'

      t = Tempfile.new(name)
      t.puts(contents) unless contents.nil?
      t.close
      yield t
      t.unlink
    end
  end
end
