module Reginald
  module AV
    class Pin
      attr_accessor :owner, :name, :connection, :graphs

      def initialize(owner, name = nil)
        @owner, @name = owner, name
        @graphs = []
      end

      def connect(other_pin)
        raise PinInUse if connection || other_pin.connection

        self.connection = other_pin
        other_pin.connection = self
      end

      def inspect
        result = "#<#{self.class.name}"
        result << " name=#{name}" if name
        result << " owner=#{owner.name}"
        result << " connection=#{connection ? connection.owner&.name : 'nil'}"
        result << ">"
        result
      end
    end

    class OutputPin < Pin
      attr_accessor :internal_connection
    end
  end
end
