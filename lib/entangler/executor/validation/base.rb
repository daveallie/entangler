# frozen_string_literal: true

module Entangler
  module Executor
    module Validation
      module Base
        protected

        def validate_opts; end

        def validate_base_dir(base_dir)
          raise Entangler::ValidationError, "Base directory doesn't exist" unless File.exist?(base_dir)
          raise Entangler::ValidationError, 'Base directory is a file' unless File.directory?(base_dir)
        end
      end
    end
  end
end
