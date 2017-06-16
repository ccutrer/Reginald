module Reginald
  module AV
    class PinInUse < RuntimeError; end
    class UnknownDevice < RuntimeError; end
  end
end
