module Account
  # Forgets a remembered device: the code is asked there again (RN-02-043).
  class TrustedDevicesController < BaseController
    def destroy
      device = current_user.trusted_devices.active.find(params[:id])
      authorize! :destroy, device
      device.revoke!
      redirect_to account_root_path, notice: t(".forgotten")
    end
  end
end
