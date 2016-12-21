require 'fileutils'

module Entangler
  class EntangledFile
    attr_accessor :desired_modtime, :action
    attr_reader :path, :contents

    def initialize(action, rel_path)
      @action = action
      @path = rel_path
      @desired_modtime = Time.now.to_i
      @contents = nil
    end

    def full_path
      Entangler.executor.generate_abs_path(@path)
    end

    def file_exists?
      File.exist?(full_path)
    end

    def process
      if action == :create || action == :update
        create_parent_directory
        write_contents
      elsif action == :delete
        delete_file
      end
    end

    private

    def create_parent_directory
      dirname = File.dirname(full_path)
      if File.exist?(dirname)
        unless File.directory?(dirname)
          FileUtils.rm dirname
          FileUtils.mkdir_p dirname
        end
      else
        FileUtils.mkdir_p dirname
      end
    end

    def write_contents
      delete_file if file_exists? && File.directory?(full_path)
      File.open(full_path, 'w') { |f| f.write(contents) }
      File.utime(File.atime(full_path), desired_modtime, full_path)
    end

    def delete_file
      FileUtils.rm_rf(full_path) if file_exists?
    end

    def marshal_dump
      if file_exists? && (action == :create || action == :update)
        @desired_modtime = File.mtime(full_path).to_i
        @contents = File.read(full_path)
      end

      [action, path, desired_modtime, contents]
    end

    def marshal_load(array)
      @action, @path, @desired_modtime, @contents = *array
    end
  end
end
