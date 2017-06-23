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
  end
end
