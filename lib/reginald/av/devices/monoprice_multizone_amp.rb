require 'rubyserial'

module Reginald::AV
  module Devices
    class MonopriceMultizoneAmp < Device
      class OutputPin < Reginald::AV::OutputPin
        attr_reader :pa, :power, :mute, :do_not_disturb, :volume, :treble, :bass, :balance, :keypad_connected

        def assign_attributes(status_line)
          parts = status_line.scan(/\d{2}/)
          raise "unrecognized status line #{status_line.inspect}" unless parts.length == 11
          # zone ID
          parts.shift
          @pa, @power, @mute, @do_not_disturb = parts[0..3].map { |xx| xx.to_i != 0 }
          @volume, @treble, @bass = parts[4..6].map(&:to_i)
          @balance = parts[7].to_i - 10
          self.internal_connection = owner.input_pins[parts[8].to_i - 1]
          @keypad_connected = parts[9].to_i != 0
        end

        def inspect
          result = "#<#{self.class.name}"
          result << " owner=#{owner.name}"
          result << " connection=#{connection ? connection.owner&.name : 'nil'}"
          [:pa, :power, :mute, :do_not_disturb, :volume, :treble, :bass, :balance, :keypad_connected].each do |attribute|
            result << " #{attribute}=#{send(attribute)}"
          end
          result << ">"
          result
        end

        def stop(graph)
          super
          owner.send(:set, self, :power, false) if graphs.empty?
        end

        def min_volume; 0.0; end
        def max_volume; 38.0; end
        def volume_units; ''; end
        def volume=(value)
          owner.send(:set, self, :volume, value.round)
        end
        def mute!
          owner.send(:set, self, :mute, true)
        end
        def unmute!
          owner.send(:set, self, :mute, false)
        end
      end

      attr_reader :stack_size

      def initialize(system, config)
        super
        @input_pins = (1..6).map { Pin.new(self) }

        if config['serial_port']
          @serial_port = Serial.new(config['serial_port'])
          # clear out any pending command
          @serial_port.write("\r\n")
          # chew up any pending input
          while (@serial_port.getbyte); end

          if check_stack_size(3)
            @stack_size = 3
          elsif check_stack_size(2)
            @stack_size = 2
          else
            @stack_size = 1
          end
        elsif (config['stack_size'])
          @stack_size = config['stack_size']
        else
          @stack_size = 1
        end

        (@stack_size * 6).times do
          @output_pins << OutputPin.new(self)
        end

        if @serial_port
          # populate the base status
          poll_status
          Thread.new do
            loop do
              sleep 0.5
              # TODO: this isn't very efficient
              system.synchronize do
                poll_status
              end
            end
          end
        end
      end

      def switch_input(output_pin, to: )
        super
        return unless @serial_port

        input = input_pins.index(to)
        set(output_pin,:power, true)
        set(output_pin, :channel, input + 1)
      end

      private

      def check_stack_size(unit)
        @serial_port.write("?#{unit}1\r\n")
        # first it echoes it back
        @serial_port.gets
        @serial_port.getbyte
        status = @serial_port.getbyte
        return false if status.nil?
        @serial_port.gets # swallow the rest of the status
      end

      def poll_status
        @stack_size.times do |i|
          @serial_port.write("?#{i + 1}0\r\n")
          # swallow the echo
          @serial_port.gets
          while true
            until @serial_port.getbyte; end
            type = @serial_port.getbyte
            break if type.nil?
            status = @serial_port.gets
            zone = status[0..1].to_i
            output_pins[(zone / 10 - 1) * 6 + zone % 10 - 1].assign_attributes(status)
          end
        end
      end

      COMMANDS = {
        pa: 'PA',
        power: 'PR',
        mute: 'MU',
        do_not_disturb: 'DT',
        volume: 'VO',
        treble: 'TR',
        bass: 'BS',
        balance: 'BL',
        channel: 'CH'
      }.freeze
      private_constant :COMMANDS

      def set(output_pin, name, value)
        output_pin.instance_variable_set("@#{name}", value) unless name == :channel
        return unless @serial_port

        protocol_value = case name
        when :pa, :power, :mute, :do_not_disturb
          value ? 1 : 0
        when :balance
          value + 10
        else
          value
        end
        @serial_port.write("<%02d%s%02d\r\n" % [zone_id(output_pin), COMMANDS[name], protocol_value])
        @serial_port.gets
      end

      def zone_id(output_pin)
        output_index = output_pins.index(output_pin)
        (output_index / 6 + 1) * 10 + output_index % 6 + 1
      end
    end
  end
end
