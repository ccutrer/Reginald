require_relative "../../../spec_helper"

require 'yaml'

module Reginald::AV
  describe System do
    describe ".new" do
      it "parses a simple configuration" do
        system = System.new(YAML.load(fixture("direct_shairport_sync.yml")))
        expect(system.devices.keys).to eq ['shairport_sync1', 'Kitchen']
        shairport = system.devices['shairport_sync1']
        expect(shairport.name).to eq "shairport_sync1"
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
    end
  end
end