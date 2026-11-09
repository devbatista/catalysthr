module Panel
  # This browser's push subscription (spec 15, RN-15-003, RN-15-004, D-654). Whoever is
  # signed in owns it: a browser that had another person's subscription passes to who
  # signed in. Open while the contract is read only, as the preferences (D-624). An
  # impersonate or a support entry only looks, so it subscribes nothing.
  class PushSubscriptionsController < BaseController
    writes_while_locked :create, :destroy

    before_action -> { head :forbidden }, if: -> { impersonating? || Current.support_access }

    def create
      authorize! :update, :own_notification_preferences
      return head :not_found unless FeatureFlags.enabled?(FeatureFlags::PUSH_NOTIFICATIONS)

      subscription = PushSubscription.find_or_initialize_by(endpoint: params[:endpoint].to_s)
      subscription.assign_attributes(user: current_user, brand: Current.brand, p256dh: params.dig(:keys, :p256dh).to_s,
        auth: params.dig(:keys, :auth).to_s, user_agent: request.user_agent.to_s.first(255))
      head(subscription.save ? :no_content : :unprocessable_content)
    end

    def destroy
      authorize! :update, :own_notification_preferences
      PushSubscription.where(user: current_user, endpoint: params[:endpoint].to_s).delete_all
      head :no_content
    end
  end
end
