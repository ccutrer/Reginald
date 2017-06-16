require_relative "../../../spec_helper"

require 'yaml'

module Reginald::AV
  describe System do
    describe ".new" do
      it "parses a simple configuration" do
        system = System.new(YAML.load(fixture("direct_shairport_sync.yml")))
        expect(system.devices.keys).to eq ['shairport_sync1', 'Kitchen']
        shairport = system.devices['shairport_sync1']
        expect(shairport.input_pins).to be_empty
        expect(shairport.output_pins.length).to eq 1
        speakers = system.devices['Kitchen']
        expect(speakers.input_pins.length).to eq 1
        expect(speakers.output_pins).to be_empty
        expect(shairport.output_pins.first.owner).to eq shairport
        expect(shairport.output_pins.first.connection).to eq speakers.input_pins.first
        expect(speakers.input_pins.first.owner).to eq speakers
        expect(speakers.input_pins.first.connection).to eq shairport.output_pins.first
      end

      it "parses a more complex configuration" do
        system = System.new(YAML.load(fixture("basic_matrix.yml")))
        expect(system.devices.keys).to eq ['shairport_sync1', 'monoprice_multizone_amp1', 'Kitchen', 'Bedroom', 'Deck']
        shairport = system.devices['shairport_sync1']
        amp = system.devices['monoprice_multizone_amp1']
        expect(amp.input_pins.length).to eq 6
        expect(amp.output_pins.length).to eq 6
        expect(amp.input_pins[0].connection).to be_nil
        expect(amp.input_pins[1].connection.owner).to eq shairport
        expect(amp.input_pins[2].connection).to be_nil
        kitchen = system.devices['Kitchen']
        bedroom = system.devices['Bedroom']
        deck = system.devices['Deck']
        expect(amp.output_pins[0].connection.owner).to eq kitchen
        expect(amp.output_pins[1].connection.owner).to eq bedroom
        expect(amp.output_pins[2].connection.owner).to eq deck
        expect(amp.output_pins[3].connection).to be_nil
      end
    end
  end
end
