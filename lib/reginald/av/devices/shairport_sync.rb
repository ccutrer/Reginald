require 'base64'
require 'nokogiri'

module Reginald
  module AV
    module Devices
      class ShairportSync < Source
        def initialize(system, config)
          super
          @output_pins = [Pin.new(self)]
          if config['metadata_pipe_name']
            File.mkfifo(config['metadata_pipe_name']) unless File.exist?(config['metadata_pipe_name'])
            Thread.new { metadata_thread }
          end
        end

        def start_graphs(system)
          graphs = Array.wrap(config['sinks']).map do |device_name|
            system.build_graph(self, system.devices[device_name])
          end

          return false if graphs.any? { |graph| !graph.conflicting_graphs.empty? }
          graphs.each(&:start)
          true
        end

        def stop
          @user_agent = nil
          output_pins.first.graphs.dup.each(&:stop)
        end

        def hidden?
          @user_agent.nil?
        end

        def display_name
          @user_agent || 'AirPlay'
        end

        private

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
              when 'ssnc'
                case code
                when 'snua'
                  system.synchronize do
                    @user_agent ||= data.sub(%r{/.*}, '')
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
