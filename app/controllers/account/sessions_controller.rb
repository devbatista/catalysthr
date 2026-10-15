module Account
  # Ends another open session of the person (RN-02-053).
  class SessionsController < BaseController
    def destroy
      session_record = current_user.user_sessions.active.where.not(id: Current.user_session&.id).find(params[:id])
      authorize! :destroy, session_record
      session_record.revoke!("ended_by_user")
      current_user.record_auth_event("session_ended", user_session_id: session_record.id)
      redirect_to account_root_path, notice: t(".ended")
    end
  end
end
