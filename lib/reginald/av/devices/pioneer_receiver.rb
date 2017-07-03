require 'socket'

module Reginald::AV
  module Devices
    class PioneerReceiver < Device
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
          return unless (telnet = input_pins.first.connection.owner.instance_variable_get(:@telnet))

          input_pins.first.connection.queue_command do
            if output_pins[0].internal_connection && output_pins[1].internal_connection
              telnet.write("3SPK\r")
            elsif output_pins[1].internal_connection
              telnet.write("2SPK\r")
            else
              telnet.write("1SPK\r")
            end
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

        def min_volume; -80.0; end
        def max_volume
          zone == 1 ? 12.0 : 0.0
        end
        def volume_units; 'dB'; end
        def volume=(value)
          case zone
            when 1
              @volume = (value * 2).round.to_f / 2
              telnet.write("%03dVL\r" % [(@volume + 80.5) * 2.to_i])
            when 2
              @volume = value.round
              telnet.write("%02dZV\r" % [@volume + 81])
            when 3
              @volume = value.round
              telnet.write("%02dYV\r" % [@volume + 81])
            when :hdzone
              @volume = value.round
              telnet.write("%02dHZV\r" % [@volume + 81])
          end
        end

        def mute!
          unless @mute
            case zone
              when 1
                telnet.write("MO\r")
              when 2
                telnet.write("Z2MO\r")
              when 3
                telnet.write("Z3MO\r")
              when :hdzone
                telnet.write("HZMO\r")
            end
            @mute = true
          end
        end

        def unmute!
          if @mute
            case zone
              when 1
                telnet.write("MF\r")
              when 2
                telnet.write("Z2MF\r")
              when 3
                telnet.write("Z3MF\r")
              when :hdzone
                telnet.write("HZMF\r")
            end
            @mute = false
          end
        end

        def queue_command(&block)
          return yield if power
          @queued_commands << block
        end

        def power=(value)
          @power = value
          if value && !@queued_commands.empty?
            queued_commands = @queued_commands
            @queued_commands = []
            queued_commands.each(&:call)
          end
        end

        private

        def poll_status
          case zone
            when 1
              telnet.write("?P\r")
              telnet.write("?V\r")
              telnet.write("?M\r")
              telnet.write("?FL\r")
            when 2
              telnet.write("?AP\r")
              telnet.write("?ZV\r")
              telnet.write("?Z2M\r")
            when 3
              telnet.write("?BP\r")
              telnet.write("?YV\r")
              telnet.write("?Z3M\r")
            when :hdzone
              telnet.write("?ZEP\r")
              telnet.write("?HZV\r")
              telnet.write("?HZM\r")
          end
        end

        def telnet
          owner.instance_variable_get(:@telnet)
        end
      end

      attr_reader :front_display

      # additional documentation:
      # ?RGD = Model
      # ?SSI = Software Version
      # ?RGC = ?
      # ?SVC = ? (boolean?)
      # ?ZEP = ? (boolean?)
      # ?STU = ? (two digits?)
      # ?RPZ = ? (boolean?)
      # ?RGK = ? (boolean?)

      def initialize(system, config)
        super

        @input_pins = (0..53).map do |i|
          pin = Pin.new(self)
          pin.config['name'] = DEFAULT_INPUTS[i] if DEFAULT_INPUTS[i]
          pin
        end
        @output_pins = []
        output_pins << OutputPin.new(self)

        if config['host']
          @telnet = TCPSocket.new(config['host'], 23)
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
          if config['zones'].include?('hdzone')
            output_pins << OutputPin.new(self, :hdzone)
          end
        end

        if @telnet
          # interrogate the input names
          input_pins.length.times do |i|
            @telnet.write("?RGB%02d\r" % i)
          end
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

      def find_input_pin(pin_config)
        case pin_config['input']
          when Integer
            input_pins[pin_config['input']]
          when String
            input_pins.find { |pin| pin.name == pin_config['input'] }
          when nil
            input_pins.first
        end
      end

      def find_output_pin(index, pin_config)
        if output_pins.first.connection&.owner.is_a?(SpeakerSelector)
          return output_pins.first.connection.owner.find_output_pin(index, pin_config)
        end
        super
      end

      def switch_input(output_pin, to: )
        if @telnet
          unless output_pin.power
            case output_pin.zone
              when 1
                @telnet.write("PO\r")
              when 2
                @telnet.write("APO\r")
              when 3
                @telnet.write("BPO\r")
              when :hdzone
                @telnet.write("ZEO\r")
            end
          end

          if output_pin.internal_connection != to
            output_pin.queue_command do
              case output_pin.zone
                when 1
                  @telnet.write("%02dFN\r" % input_pins.index(to))
                when 2
                  @telnet.write("%02dZS\r" % input_pins.index(to))
                when 3
                  @telnet.write("%02dZT\r" % input_pins.index(to))
                when :hdzone
                  @telnet.write("%02dZEA\r" % input_pins.index(to))
              end
            end
          end
        end

        super
      end

      private

      DEFAULT_INPUTS = {
          25 => "BD",
          04 => "DVD",
          06 => "SAT/CBL",
          15 => "DVR/BDR",
          19 => "HDMI 1",
          20 => "HDMI 2",
          21 => "HDMI 3",
          22 => "HDMI 4",
          23 => "HDMI 5",
          24 => "HDMI 6",
          34 => "HDMI 7",
          38 => "INTERNET RADIO",
          41 => "PANDORA",
          53 => "Spotify",
          44 => "MEDIA SERVER",
          45 => "FAVORITES",
          17 => "iPod/USB",
          13 => "USB-DAC",
          05 => "TV",
          01 => "CD",
          02 => "TUNER",
          00 => "PHONO",
          12 => "MULTI CH IN",
          33 => "DAPTER PORT/BT AUDIO"
      }.freeze

      def self.fl_charset
        charset = (0..255).map do |chr|
          chr.chr.force_encoding(Encoding::ISO_8859_1).encode(Encoding::UTF_8)
        end
        # custom Pioneer changes
        charset[0x08] = "Ⅱ"
        charset[0x09] = "◀" # left arrow
        charset[0x0a] = "▶" # right arrow
        charset[0x0b] = "♡" # heart
        charset[0x0c] = "."
        charset[0x0d] = ".0"
        charset[0x0e] = ".5"
        charset[0x0f] = "Ω" # ohms
        charset[0x10] = "⁰" # superscripts
        charset[0x11] = "1"
        charset[0x12] = "²"
        charset[0x13] = "³"
        charset[0x14] = "⁴"
        charset[0x15] = "⁵"
        charset[0x16] = "⁶"
        charset[0x17] = "⁷"
        charset[0x18] = "⁸"
        charset[0x19] = "⁹"
        charset[0x1a] = "ᴬ"
        charset[0x1b] = "ᴮ"
        charset[0x1c] = "C"
        charset[0x1d] = "F"
        charset[0x1e] = "ᴹ"
        charset[0x1f] = "‾" # overline

        charset[0x60] = "‖" # double pipe

        charset[0x7f] = "█" # solid block
        charset[0x80] = "Œ" # OE ligature
        charset[0x81] = "œ" # oe ligature
        charset[0x82] = "Ĳ" # IJ ligature
        charset[0x83] = "ĳ" # ij ligature
        charset[0x84] = "π" # lowercase pi
        charset[0x85] = "∓" # -/+

        charset[0x8c] = "←" # left arrow
        charset[0x8d] = "↑" # up arrow
        charset[0x8e] = "→" # right arrow
        charset[0x8f] = "↓" # down arrow
        charset[0x90] = "+" # small plus
        charset[0x91] = "♪" # eighth note
        charset[0x92] = "📁" # folder

        charset[0x99] = "🔁🔀" # repeat and shuffle
        charset[0x9a] = "🔁" # repeat
        charset[0x9b] = "🔀" # shuffle
        charset[0x9c] = "▲▼" # up and down
        charset[0x9d] = "[)" # dolby digital left D
        charset[0x9e] = "(]" # dolby digital right D
        charset[0x9f] = "Ⅰ"

        charset
      end

      FL_CHARSET = fl_charset.freeze
      private_constant :FL_CHARSET

      def hd_zone
        output_pins.find { |pin| pin.zone == :hdzone }
      end

      def poll_status(timeout: nil)
        return false unless IO.select([@telnet], nil, nil, timeout)
        line = @telnet.gets.strip
        puts "Received '#{line}' from #{name}"
        system.synchronize do
          case line
            when /^PWR([01])$/
              output_pins[0].power = $1 == '0'
            when /^VOL(\d{3})$/
              output_pins[0].instance_variable_set(:@volume, $1.to_f / 2 - 80.5)
            when /^MUT([01])$/
              output_pins[0].instance_variable_set(:@mute, $1 == '0')
            when /^FN(\d{2})$/
              output_pins[0].internal_connection = input_pins[$1.to_i]
            when /^APR([01])$/
              output_pins[1].instance_variable_set(:@power, $1 == '0')
            when /^ZV(\d{2})$/
              output_pins[1].instance_variable_set(:@volume, $1.to_f - 81)
            when /^Z2MUT([01])$/
              output_pins[1].instance_variable_set(:@mute, $1 == '0')
            when /^Z2F(\d{2})$/
              output_pins[1].internal_connection = input_pins[$1.to_i]
            when /^BPR([01])$/
              output_pins[2].instance_variable_set(:@power, $1 == '0')
            when /^YV(\d{2})$/
              output_pins[2].instance_variable_set(:@volume, $1.to_f - 81)
            when /^Z3MUT([01])$/
              output_pins[2].instance_variable_set(:@mute, $1 == '0')
            when /^Z3F(\d{2})$/
              output_pins[2].internal_connection = input_pins[$1.to_i]
            when /^ZEP([01])$/
              hd_zone.instance_variable_set(:@power, $1 == '0')
            when /^XV(\d{2})$/
              hd_zone.instance_variable_set(:@volume, $1.to_f - 81)
            when /^HZMUT([01])$/
              hd_zone.instance_variable_set(:@mute, $1 == '0')
            when /^ZEA(\d{2})$/
              hd_zone.internal_connection = input_pins[$1.to_i]
            when /^FL(\X{30})$/
              @front_display = $1[2..-1].scan(/\X{2}/).map { |x| FL_CHARSET[x.to_i(16)] }.join('')
              puts "Front Display: #{front_display}"
            when /^RGB(\d{2})\d(.*)$/
              pin = input_pins[$1.to_i]
              pin.config['name'] = $2
          end
        end
        true
      end
    end
  end
end
