module Entangler
  module EntangledFileComponents
    module LRDLogic
      private

      def with_empty_temp_file
        temp_empty_file = Tempfile.new('empty_file')
        yield temp_empty_file
        close_and_unlink(temp_empty_file)
      end

      def lrd_patch(output_file)
        if File.exist?(full_path)
          LibRubyDiff.patch(full_path, delta_file.path, output_file.path)
        else
          with_empty_temp_file do |temp_empty_file|
            LibRubyDiff.patch(temp_empty_file.path, delta_file.path, output_file.path)
          end
        end
        output_file.rewind
      end

      def lrd_signature(output_file)
        if File.exist?(full_path)
          LibRubyDiff.signature(full_path, output_file.path)
        else
          with_empty_temp_file do |temp_empty_file|
            LibRubyDiff.signature(temp_empty_file.path, output_file.path)
          end
        end
        output_file.rewind
      end

      def lrd_delta(output_file)
        LibRubyDiff.delta(full_path, signature_file.path, output_file.path)
        output_file.rewind
      end
    end
  end
end
