module Reginald
  module AV
    Pin = Struct.new(:owner, :name, :connection) do
      def connect(other_pin)
        raise PinInUse if connection || other_pin.connection

        self.connection = other_pin
        other_pin.connection = self
      end
    end
  end
end
