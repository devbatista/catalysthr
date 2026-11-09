module Notifications
  # Sends a notice to every subscription of the person in the brand (RN-15-003, RN-15-004,
  # P-15-31). A subscription the service says is gone (404, 410) is deleted (RN-15-080). A
  # temporary failure gets 3 new attempts, 1, 5 and 15 minutes apart, only for the
  # subscriptions that failed, so no device gets it twice (RN-15-084). The delivery is sent
  # when at least one device took it. Notices of the same type released together go as one
  # message (RN-15-034).
  class DeliverPushJob < ApplicationJob
    queue_as :notifications

    WAITS = [ 1.minute, 5.minutes, 15.minutes ].freeze
    BODY_LIMIT = 140

    def perform(delivery, subscription_ids = nil, attempt = 0)
      return unless delivery.queued? || delivery.sending?

      notification = delivery.notification
      subscriptions = PushSubscription.where(user_id: notification.recipient_user_id, brand_id: notification.brand_id)
      subscriptions = subscriptions.where(id: subscription_ids) if subscription_ids
      return finish(delivery, "failed", failed_reason: "no_subscription") if subscriptions.none? && delivery.sent_at.nil?

      delivery.update!(status: "sending", attempts: delivery.attempts + 1)
      message = message_for(delivery)
      results = subscriptions.to_h { |subscription| [ subscription, push(subscription, message, notification.urgent) ] }
      delivery.update!(sent_at: Time.current) if delivery.sent_at.nil? && results.value?(:sent)

      pending = results.select { |_, result| result == :temporary }.keys
      if pending.any? && attempt < WAITS.size
        self.class.set(wait: WAITS[attempt]).perform_later(delivery, pending.map(&:id), attempt + 1)
      elsif delivery.sent_at
        finish(delivery, "sent", sent_at: delivery.sent_at)
      else
        finish(delivery, "failed", failed_reason: (results.values - [ :gone ]).last&.to_s || "no_subscription")
      end
    end

    private

    # The delivery and the ones grouped into it share the result, so each mandatory notice
    # that failed looks for its next channel (RN-15-081).
    def finish(delivery, status, **attributes)
      [ *delivery.grouped.to_a, delivery ].each { |one| one.update!(status: status, **attributes) }
    end

    def push(subscription, message, urgent)
      PushSender.deliver(subscription, message, urgent: urgent)
      subscription.update_columns(last_success_at: Time.current)
      :sent
    rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
      subscription.destroy!
      :gone
    rescue *PushSender::TEMPORARY
      :temporary
    rescue WebPush::ResponseError => error
      # Wrong keys or a refused message: nothing the person can do, so the team is told.
      Rails.error.report(error, context: { subscription_id: subscription.id })
      error.class.name.demodulize.underscore.to_sym
    end

    def message_for(delivery)
      notification = delivery.notification
      others = delivery.grouped.count
      type = notification.type
      texts = if !type.channels.include?("push")
        # A fallback of a type written for the e-mail, as an invoice with its amount: only
        # the type's name reaches the screen (RN-15-005, D-654).
        { title: I18n.t("notification_types.#{type.code}.name"), body: nil, path: "/notifications/#{notification.id}" }
      elsif others.zero?
        { title: notification.title, body: notification.body.to_s.truncate(BODY_LIMIT), path: "/notifications/#{notification.id}" }
      else
        { title: I18n.t("notification_types.#{type.code}.grouped", count: others + 1), body: nil,
          path: notification.path.start_with?("/portal") ? "/portal/notifications" : "/notifications" }
      end
      texts.merge(tag: notification.id, icon: icon_of(notification.brand)).to_json
    end

    def icon_of(brand)
      icon = brand.pwa_icon_small
      return "/icon.png" unless icon.attached?

      Rails.application.routes.url_helpers.brand_asset_path(kind: :pwa_icon_small, v: icon.blob_id)
    end
  end
end
