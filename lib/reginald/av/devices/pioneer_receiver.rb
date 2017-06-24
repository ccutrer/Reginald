module Reginald::AV
  module Devices
    class PioneerReceiver < Device
      def initialize(system, config)
        super
        # TODO: configure based on the zone capabilities of the receiver
        @input_pins = (1..5).map { Pin.new(self) }
        @output_pins = (1..2).map { OutputPin.new(self) }
      end
    end
  end
end
