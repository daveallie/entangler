module Entangler
  class EntanglerError < StandardError; end
  class ValidationError < EntanglerError; end
  class VersionMismatchError < EntanglerError; end
end
