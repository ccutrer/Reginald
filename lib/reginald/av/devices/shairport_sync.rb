require 'base64'
require 'nokogiri'

module Reginald
  module AV
    module Devices
      class ShairportSync < Source
        class Pin < ::Reginald::AV::Pin
          def start(graph)
            super
            owner.send(:add_graph, graph)
          end

          def stop(graph)
            super
            owner.send(:remove_graph, graph)
          end
        end

        def initialize(system, config)
          super
          @output_pins = [Pin.new(self)]
          if config['metadata_pipe_name']
            File.mkfifo(config['metadata_pipe_name']) unless File.exist?(config['metadata_pipe_name'])
            Thread.new { metadata_thread }
          end
          @volume_multipliers = {}
        end

        def start_graphs(system)
          graphs = Array.wrap(config['sinks']).map do |device_name|
            system.build_graph(self, system.devices[device_name])
          end

          return false if graphs.any? { |graph| !graph.conflicting_graphs.empty? }
          graphs.each(&:start)
          if graphs.length == 1
            # a single graph? source directly controls the volume with no scaling
            @volume_multipliers[graphs.first] = 1.0
          end
          set_volume(@volume) if @volume
          true
        end

        def stop
          @user_agent = nil
          @artist = nil
          @album = nil
          @track = nil
          @volume = nil
          output_pins.first.graphs.dup.each(&:stop)
        end

        def hidden?
          @user_agent.nil?
        end

        def display_name
          @user_agent || 'AirPlay'
        end

        private

        def add_graph(graph)
          if @volume && (volume_pin = graph.volume_pin)
            # scale both volumes to 0-100% to get a valid ratio
            volume_percentage = System.scale_volume(@volume, -30.0, 0.0, 0.0, 100.0)
            graph_percentage = System.scale_volume(volume_pin.volume, volume_pin.min_volume, volume_pin.max_volume, 0.0, 100.0)
            @volume_multipliers[graph] = graph_percentage / volume_percentage
          end
        end

        def remove_graph(graph)
          @volume_multipliers.delete(graph)
          # down to a single running graph? pin its volume to the source's requested volume
          if @volume_multipliers.length == 1
            @volume_multipliers[@volume_multipliers.keys.first] = 1.0
          end
        end

        def set_volume(volume)
          if @volume.nil?
            output_pins.first.graphs.each do |graph|
              add_graph(graph)
            end
          end

          @volume = volume
          output_pins.first.graphs.each do |graph|
            volume_pin = graph.volume_pin
            next unless volume_pin

            # mute
            if volume == -144.0
              volume_pin.mute!
              next
            end
            volume_pin.unmute!

            # scale it to 100% so that the multiplier makes sense
            graph_volume = System.scale_volume(volume, -30.0, 0.0, 0.0, 100.0)
            # adjust it
            graph_volume = @volume_multipliers[graph] * graph_volume
            # now scale it to the target device's scale
            volume_pin.volume = System.scale_volume(graph_volume, 0.0, 100.0, volume_pin.min_volume, volume_pin.max_volume)
          end
        end

        def metadata_thread
          loop do
            metadata_pipe = File.open(config['metadata_pipe_name'], 'rb')
            loop do
              begin
                item_xml = metadata_pipe.readline
              rescue EOFError
                break
              end

              item = Nokogiri::XML(item_xml)

              type = [item.at_css('item type')].pack("H*")
              code = [item.at_css('item code')].pack("H*")
              length = item.at_css('item length').text.to_i

              if length > 0
                data_header = metadata_pipe.readline
                raise "Invalid data header #{data_header.inspect}" unless data_header == "<data encoding=\"base64\">\n"

                data_base64 = metadata_pipe.read(((length + 2) / 3) * 4)
                data = Base64.decode64(data_base64)

                data_footer = metadata_pipe.readline
                raise "Invalid data footer  #{data_footer.inspect}" unless data_footer == "</data></item>\n"
              end

              case type
              when 'core'
                case code
                when 'asal'
                  system.synchronize do
                    @album = data
                  end
                when 'asar'
                  system.synchronize do
                    @artist = data
                  end
                when 'minm'
                  system.synchronize do
                    @track = data
                  end
                end
              when 'ssnc'
                case code
                when 'snua'
                  system.synchronize do
                    @user_agent ||= data.sub(%r{/.*}, '')
                  end
                when 'pvol'
                  system.synchronize do
                    volume = data.split(',').first.to_f
                    set_volume(volume)
                  end
                end
              end
            end
          end
        rescue
          puts $!.inspect
          puts $!.backtrace
        end
      end
    end
  end
end
