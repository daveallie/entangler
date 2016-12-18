require 'lib_ruby_diff'
require 'tempfile'
require_relative 'entangled_file_components/lrd_logic'
require_relative 'entangled_file_components/marshal_logic'

module Entangler
  class EntangledFile
    include Entangler::EntangledFileComponents::LRDLogic,
            Entangler::EntangledFileComponents::MarshalLogic
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
      lrd_patch(tempfile)
      File.open(full_path, 'w') { |f| f.write(tempfile.read) }
      close_and_unlink(tempfile)
      File.utime(File.atime(full_path), @desired_modtime, full_path)
    end

    private

    def signature_exists?
      defined?(@signature_tempfile)
    end

    def signature_file
      return @signature_tempfile if signature_exists?
      @signature_tempfile = Tempfile.new('sig_file')
      lrd_signature(@signature_tempfile)
      @signature_tempfile
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
      lrd_delta(@delta_tempfile)
      @delta_tempfile
    end

    def delta
      delta_file.read
    end

    def close_and_unlink(file)
      file.close
      file.unlink
    end

    def close_and_unlink_files
      if signature_exists?
        close_and_unlink @signature_tempfile
        @signature_tempfile = nil
      end

      return unless delta_exists?
      close_and_unlink @delta_tempfile
      @delta_tempfile = nil
    end
  end
end
