module Account
  # Changing the password ends the other sessions and forgets the remembered devices
  # (RN-02-043, RN-02-053); this session stays open.
  class PasswordsController < BaseController
    def edit
      authorize! :manage, :own_security
    end

    def update
      authorize! :manage, :own_security
      if current_user.update_with_password(params.expect(user: %i[current_password password password_confirmation]))
        bypass_sign_in(current_user)
        redirect_to account_root_path, notice: t(".updated")
      else
        render :edit, status: :unprocessable_content
      end
    end
  end
end
