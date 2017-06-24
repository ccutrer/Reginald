module Reginald::AV
  module Devices
    class VirtualMatrix < Device

      def initialize(system, config)
        super

        @output_pins = config['output'].map do |output_pin_config|
          OutputPin.new(self, output_pin_config)
        end
      end

      # dynamically create new pins as devices are connected
      def find_input_pin(pin_config)
        new_pin = Pin.new(self, pin_config)
        @input_pins << new_pin
        new_pin
      end
    end
  end
end
