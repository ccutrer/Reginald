require 'socket'

module Reginald::AV
  module Devices
    class OnkyoReceiver < Device
      class SpeakerSelector < Device
        class OutputPin < Reginald::AV::OutputPin
          def stop(graph)
            super
            self.internal_connection = nil if graphs.empty?
            owner.send(:switch_speakers)
          end
        end

        def initialize
          @input_pins = [Pin.new(self)]
          @output_pins = [OutputPin.new(self), OutputPin.new(self)]
        end

        def switch_input(output_pin, to: )
          super
          switch_speakers
        end

        private

        def switch_speakers
          amp = input_pins.first.connection.owner
          if output_pins[0].internal_connection && output_pins[1].internal_connection
            amp.send(:send_command, "SPLAB")
          elsif output_pins[1].internal_connection
            amp.send(:send_command, "SPLB")
          else
            amp.send(:send_command, "SPLA")
          end
        end
      end

      class OutputPin < Reginald::AV::OutputPin
        attr_reader :zone, :power, :mute, :volume

        def initialize(owner, zone = 1)
          super(owner)
          @zone = zone
          @queued_commands = []
        end

        def inspect
          result = "#<#{self.class.name}"
          result << " owner=#{owner.name}"
          result << " connection=#{connection ? connection.owner&.name : 'nil'}"
          [:power, :mute, :volume].each do |attribute|
            result << " #{attribute}=#{send(attribute)}"
          end
          result << ">"
          result
        end

        def min_volume; -81.5; end
        def max_volume
          zone == 1 ? 16.5 : 0.0
        end
        def volume_units; 'dB'; end
        def volume=(value)
          case zone
            when 1
              @volume = (value * 2).round.to_f / 2
              owner.send(:send_command, "MVL%02x" % ((@volume + 82) * 2).to_i)
            when 2
              @volume = value.round
              owner.send(:send_command, "ZVL%02x" % ((@volume + 82) * 2).to_i)
            when 3
              @volume = value.round
              owner.send(:send_command, "VL3%02x" % ((@volume + 82) * 2).to_i)
          end
        end

        def mute!
          unless @mute
            case zone
              when 1
                owner.send(:send_command, "AMT01")
              when 2
                owner.send(:send_command, "ZMT01")
              when 3
                owner.send(:send_command, "MT301")
            end
            @mute = true
          end
        end

        def unmute!
          if @mute
            case zone
              when 1
                owner.send(:send_command, "AMT00")
              when 2
                owner.send(:send_command, "ZMT00")
              when 3
                owner.send(:send_command, "MT300")
            end
            @mute = false
          end
        end

        def stop(graph)
          super
          if graphs.empty?
            case zone
            when 1
              owner.send(:send_command, "PWR00")
            when 2
              owner.send(:send_command, "ZPW00")
            when 3
              owner.send(:send_command, "PW300")
            end
          end
        end

        private

        def poll_status
          case zone
            when 1
              owner.send(:send_command, "PWRQSTN")
              owner.send(:send_command, "MVLQSTN")
              owner.send(:send_command, "AMTQSTN")
            when 2
              owner.send(:send_command, "ZPWQSTN")
              owner.send(:send_command, "ZVLQSTN")
              owner.send(:send_command, "ZMTQSTN")
            when 3
              owner.send(:send_command, "PW3QSTN")
              owner.send(:send_command, "VL3QSTN")
              owner.send(:send_command, "MT3QSTN")
          end
        end
      end

      attr_reader :front_display

      def initialize(system, config)
        super

        @input_pins = (1..0x57).map do |i|
          pin = Pin.new(self)
          pin.config['name'] = DEFAULT_INPUTS[i] if DEFAULT_INPUTS[i]
          pin
        end
        @output_pins = []
        output_pins << OutputPin.new(self)

        if config['host']
          @socket = TCPSocket.new(config['host'], 60128)
        end

        # I _could_ detect these with the speaker system configuration,
        # but that doesn't work if the receiver is off. so put it in the
        # config
        if config['speaker_b']
          speaker_selector = SpeakerSelector.new
          output_pins.first.connect(speaker_selector.input_pins.first)
        end
        if config['zones']
          if config['zones'].include?(2)
            output_pins << OutputPin.new(self, 2)
          end
          if config['zones'].include?(3)
            output_pins << OutputPin.new(self, 3)
          end
        end

        if @socket
          # populate the initial status
          output_pins.each do |pin|
            pin.send(:poll_status)
          end
          # read all pending messages
          while poll_status(timeout: 0.0); end
          Thread.new do
            loop do
              poll_status
            end
          end
        end
      end

      def find_output_pin(index, pin_config)
        if output_pins.first.connection&.owner.is_a?(SpeakerSelector)
          return output_pins.first.connection.owner.find_output_pin(index, pin_config)
        end
        super
      end

      def switch_input(output_pin, to: )
        if @socket
          unless output_pin.power
            case output_pin.zone
              when 1
                send_command("PWR01")
              when 2
                send_command("ZPW01")
              when 3
                send_command("PW301")
            end
          end

          if output_pin.internal_connection != to
            case output_pin.zone
            when 1
              send_command("SLI%02x" % (input_pins.index(to) + 1))
            when 2
              send_command("SLZ%02x" % (input_pins.index(to) + 1))
            when 3
              send_command("SL3%02x" % (input_pins.index(to) + 1))
            end
          end
        end

        super
      end

      private

      DEFAULT_INPUTS = {
          0x01 => "CBL/SAT",
          0x02 => "GAME",
          0x03 => "AUX",
          0x10 => "BD/DVD",
          0x11 => "STRM BOX",
          0x12 => "TV",
          0x22 => "PHONO",
          0x23 => "CD",
          0x24 => "FM",
          0x25 => "AM",
          0x26 => "TUNER",
          0x29 => "USB",
          0x2B => "NET",
          0x2E => "BT AUDIO",
          0x55 => "HDMI 5",
          0x56 => "HDMI 6",
          0x57 => "HDMI 7"
      }.freeze

      def send_command(command)
        header = ["ISCP", 16, command.length + 3, 1, "\x0\x0\x0!1"].pack("a4L>L>Ca5")
        @socket.write(header + command + "\r")
      end

      def read_reply
        header = @socket.read(16)
        signature, header_length, data_length, version, _reserved = header.unpack("a4L>L>Ca3")
        raise "Invalid ISCP header" unless signature == "ISCP"
        raise "Invalid ISCP header length #{header_length}" unless header_length == 16
        raise "Unrecognized ISCP version #{version}" unless version == 1
        data = @socket.read(data_length)
        raise "Invalid data trailer" unless data[-3..-1] == "\x1a\r\n"
        raise "Invalid data header" unless data[0..1] == "!1"
        data[2...-3]
      end

      def poll_status(timeout: nil)
        return false unless IO.select([@socket], nil, nil, timeout)

        line = read_reply
        puts "Received '#{line}' from #{name}"
        system.synchronize do
          case line
          when /^PWR(00|01)$/
            output_pins[0].instance_variable_set(:@power, $1 == '01')
          when /^MVL(\X{2})$/
            output_pins[0].instance_variable_set(:@volume, $1.to_i(16).to_f / 2 - 82)
          when /^AMT(00|01)$/
            output_pins[0].instance_variable_set(:@mute, $1 == '01')
          when /^SLI(\X{2})$/
            output_pins[0].internal_connection = input_pins[$1.to_i(16) - 1]
          when /^ZPW(00|01)$/
            output_pins[1].instance_variable_set(:@power, $1 == '01')
          when /^ZVL(\X{2})$/
            output_pins[1].instance_variable_set(:@volume, $1.to_i(16).to_f - 82)
          when /^ZMT(00|01)$/
            output_pins[1].instance_variable_set(:@mute, $1 == '01')
          when /^SLZ(\X{2})$/
            output_pins[1].internal_connection = input_pins[$1.to_i(16) - 1]
          when /^PW3(00|01)$/
            output_pins[2].instance_variable_set(:@power, $1 == '01')
          when /^VL3(\X{2})$/
            output_pins[2].instance_variable_set(:@volume, $1.to_i(16).to_f - 82)
          when /^MT3(00|01)$/
            output_pins[2].instance_variable_set(:@mute, $1 == '01')
          when /^SL3(\X{2})$/
            output_pins[2].internal_connection = input_pins[$1.to_i(16) - 1]
          when /^FLD(.*)$/
            @front_display = [$1].pack("H*").force_encoding(Encoding::UTF_8)
            puts "Front Display: #{front_display}"
          end
        end
        true
      end
    end
  end
end
