module Reginald::AV
  module Devices
    class MonopriceMultizoneAmp < Device
      attr_reader :stack_size

      def initialize(config)
        super
        @input_pins = (1..6).map { Pin.new(self) }
        # could be stacked; prefer autodiscovery > config > assume one
        # autodiscover
        if (false)
        elsif (config[:stack_size])
          @stack_size = config[:stack_size]
        else
          @stack_size = 1
        end

        (@stack_size * 6).times do
          @output_pins << OutputPin.new(self)
        end
      end
    end
  end
end
