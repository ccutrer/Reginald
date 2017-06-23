module Reginald
  module AV
    class Device
      attr_reader :config, :input_pins, :output_pins
      attr_accessor :name

      def initialize(config)
        @config = config
        @name = config['name']
        @input_pins = []
        @output_pins = []
      end

      def conflicting_graphs_for(output_pin, to: )
        return [] if output_pin.internal_connection == to
        output_pin.graphs
      end

      def switch_input(output_pin, to: )
        raise PinInUse unless conflicting_graphs_for(output_pin, to: to).empty?
        output_pin.internal_connection = to
      end

      def find_input_pin(pin_config)
        case pin_config['input']
        when Integer
          input_pins[pin_config['input'] - 1]
        when String
          input_pins.find { |pin| pin.name == pin_config['input'] }
        when nil
          input_pins.first
        end
      end
    end

    class Source < Device
      def hidden?
        false
      end
    end

    class Sink < Device
    end
  end
end