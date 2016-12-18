require 'lib_ruby_diff'
require 'tempfile'

module Entangler
  class EntangledFile
    # 0: file initialized
    # 1: sig loaded
    # 2: delta loaded
    attr_accessor :state
    attr_accessor :desired_modtime
    attr_reader :path

    def initialize(rel_path)
      @path = rel_path
      @state = 0
      @desired_modtime = Time.now.to_i
    end

    def done?
      @state == 2
    end

    def full_path
      Entangler.executor.generate_abs_path(@path)
    end

    def file_exists?
      File.exist?(full_path)
    end

    def export
      raise "Delta file doesn't exist when creaing patched file" unless delta_exists?
      tempfile = Tempfile.new('final_file')
      if File.exist?(full_path)
        LibRubyDiff.patch(full_path, delta_file.path, tempfile.path)
      else
        temp_empty_file = Tempfile.new('empty_file')
        LibRubyDiff.patch(temp_empty_file.path, delta_file.path, tempfile.path)
      end
      tempfile.rewind
      File.open(full_path, 'w') { |f| f.write(tempfile.read) }
      tempfile.close
      tempfile.unlink
      File.utime(File.atime(full_path), @desired_modtime, full_path)
    end

    private

    def signature_exists?
      defined?(@signature_tempfile)
    end

    def signature_file
      return @signature_tempfile if signature_exists?
      @signature_tempfile = Tempfile.new('sig_file')
      if File.exist?(full_path)
        LibRubyDiff.signature(full_path, @signature_tempfile.path)
      else
        temp_empty_file = Tempfile.new('empty_file')
        LibRubyDiff.signature(temp_empty_file.path, @signature_tempfile.path)
      end
      @signature_tempfile.rewind
      @signature_tempfile
    end

    def write_signature(contents)
      @signature_tempfile = Tempfile.new('sig_file')
      @signature_tempfile.write(contents)
      @signature_tempfile.rewind
    end

    def signature
      signature_file.read
    end

    def delta_exists?
      defined?(@delta_tempfile)
    end

    def delta_file
      return @delta_tempfile if delta_exists?
      raise "Signature file doesn't exist when creaing delta" unless signature_exists?

      @delta_tempfile = Tempfile.new('delta_file')
      LibRubyDiff.delta(full_path, signature_file.path, @delta_tempfile.path)
      @delta_tempfile.rewind
      @delta_tempfile
    end

    def write_delta(contents)
      @delta_tempfile = Tempfile.new('delta_file')
      @delta_tempfile.write(contents)
      @delta_tempfile.rewind
    end

    def delta
      delta_file.read
    end

    def close_and_unlink_files
      if signature_exists?
        @signature_tempfile.close
        @signature_tempfile.unlink
        @signature_tempfile = nil
      end

      return unless delta_exists?
      @delta_tempfile.close
      @delta_tempfile.unlink
      @delta_tempfile = nil
    end

    def marshal_dump
      last_arg = nil

      case @state
      when 0
        last_arg = signature_file.read
      when 1
        @desired_modtime = File.mtime(full_path).to_i
        last_arg = delta_file.read
      end

      @state += 1 if @state < 2

      close_and_unlink_files

      [@path, @state, @desired_modtime, last_arg]
    end

    def marshal_load(array)
      @path, @state, @desired_modtime, last_arg = *array

      if @state == 1
        write_signature(last_arg)
      elsif @state == 2
        write_delta(last_arg)
      end
    end
  end
end
