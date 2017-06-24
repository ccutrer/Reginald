# handle events from ShairportSync
class Reginald::Av::ShairportSyncController < ApplicationController
  before_action :find_device
  skip_before_action :verify_authenticity_token

  def create
    return render plain: "Instance Busy", status: 400 unless @device.output_pins.first.graphs.empty?

    return render plain: "Conflict occurred", status: 503 unless @device.start_graphs(system)
    # need to tell Shairport Sync which device it connected to if necessary
    render plain: @device.output_pins.first.connection&.config&.[]('alsa_device') || 'OK'
  end

  def destroy
    @device.stop

    render plain: 'OK'
  end

  private

  def find_device
    @device = system.devices[params[:id]]
    return render plain: "Device not found", status: 404 unless @device.is_a?(Reginald::AV::Devices::ShairportSync)
  end
end
