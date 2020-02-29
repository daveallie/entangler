# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'to_regexp'
require 'entangler'
require 'entangler/executor/base'
require 'entangler/executor/master'
require 'entangler/executor/slave'
require 'tmpdir'

def with_temp_dirs(num, dirs = [], &block)
  if num.zero?
    yield(dirs)
  else
    Dir.mktmpdir do |dir|
      with_temp_dirs(num - 1, dirs + [dir], &block)
    end
  end
end

def with_temp_dir
  with_temp_dirs(1) do |dirs|
    yield dirs.first
  end
end
