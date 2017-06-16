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

      def find_input_pin(index_or_name)
        if index_or_name.is_a?(String)
          input_pins.find { |pin| pin.name == index_or_name }
        else
          input_pins[index_or_name - 1]
        end
      end

      def find_output_pin(index_or_name)
        if index_or_name.is_a?(String)
          output_pins.find { |pin| pin.name == index_or_name }
        else
          output_pins[index_or_name - 1]
        end
      end

    end
  end
end