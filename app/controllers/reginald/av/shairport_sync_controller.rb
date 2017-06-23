# handle events from ShairportSync
class Reginald::Av::ShairportSyncController < ApplicationController
  before_action :find_device

  def create
    return render text: "Instance Busy", status: 400 unless @device.output_pins.graphs.empty?

    return render text: "Conflict occurred", status: 503 unless @device.start_graphs(system)
    # need to tell Shairport Sync which device it connected to if necessary
    render text: @device.output_pins.first.connection.config['alsa_device'] || 'OK'
  end

  private

  def find_device
    @device = system.devices[params[:id]]
    return render text: "Device not found", status: 404 unless @device.is_a?(Reginald::AV::Devices::ShairportSync)
  end
end
