module Entangler
  module EntangledFileComponents
    module MarshalLogic
      private

      def write_signature(contents)
        @signature_tempfile = Tempfile.new('sig_file')
        @signature_tempfile.write(contents)
        @signature_tempfile.rewind
      end

      def write_delta(contents)
        @delta_tempfile = Tempfile.new('delta_file')
        @delta_tempfile.write(contents)
        @delta_tempfile.rewind
      end

      def marshal_dump
        last_arg = nil

        if @state.zero?
          last_arg = signature_file.read
        elsif @state == 1
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
end
