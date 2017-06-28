require_relative "../../../../spec_helper"

require 'yaml'

# this is normally autoloaded by the config
require 'reginald/av/devices/shairport_sync'

module Reginald::AV
  describe Devices::ShairportSync do
    let(:system) { System.new(YAML.load(fixture("virtual_matrix.yml"))) }

    describe "#start_graphs" do
      it "starts multiple graphs" do
        party = system.devices['shairport_sync_party_mode']
        expect(party.start_graphs(system)).to eq true
        expect(party.output_pins.first.graphs.length).to eq 2
      end

      it "returns false -- without starting any graphs -- if one of them is not possible" do
        bedroom = system.devices['shairport_sync_bedroom']
        bedroom.start_graphs(system)
        expect(system.graphs.length).to eq 1

        party = system.devices['shairport_sync_party_mode']
        expect(party.start_graphs(system)).to eq false
        expect(party.output_pins.first.graphs.length).to eq 0
        expect(system.graphs.length).to eq 1
      end
    end

    describe "#set_volume" do
      let(:speaker1) { system.devices['Kitchen'].input_pins.first.connection }
      let(:speaker2) { system.devices['Bedroom'].input_pins.first.connection }
      let(:shairport) { system.devices['shairport_sync_party_mode'] }

      it "keeps volume consistent" do
        speaker1.volume = 19
        speaker2.volume = 19
        shairport.send(:set_volume, -15.0)
        shairport.start_graphs(system)

        expect(speaker1.volume).to eq 19
        expect(speaker2.volume).to eq 19

        shairport.send(:set_volume, -22.5)

        expect(speaker1.volume).to eq 10
        expect(speaker2.volume).to eq 10

        shairport.send(:set_volume, 0.0)

        expect(speaker1.volume).to eq 38
        expect(speaker2.volume).to eq 38
      end

      it "scales different volumes consistently" do
        speaker1.volume = 15
        speaker2.volume = 30
        shairport.send(:set_volume, -15.0)
        shairport.start_graphs(system)

        expect(speaker1.volume).to eq 15
        expect(speaker2.volume).to eq 30

        shairport.send(:set_volume, -22.5)

        expect(speaker1.volume).to eq 8
        expect(speaker2.volume).to eq 15

        shairport.send(:set_volume, 0.0)

        expect(speaker1.volume).to eq 30
        expect(speaker2.volume).to eq 38
      end
    end
  end
end
