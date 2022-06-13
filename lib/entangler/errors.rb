# frozen_string_literal: true

module Entangler
  class EntanglerError < StandardError; end
  class ValidationError < EntanglerError; end
  class VersionMismatchError < EntanglerError; end
  class NotInstalledOnRemoteError < EntanglerError; end
end
