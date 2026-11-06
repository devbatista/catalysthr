# Creates the notices of the catalog (spec 15). The other specs say when a notice is born;
# this module says how it reaches the person (section 1):
# - the bell, when the type has the "system" channel (D-608);
# - a delivery for each external channel the person chose (their own choice, then the
#   company's default, then the catalog's, RN-15-020 to RN-15-022) and can get (RN-15-023,
#   RN-15-083, D-609). The push waits for the quiet hours (RN-15-030); WhatsApp comes later.
# - a mandatory notice left without a channel, or whose delivery failed, goes to the next
#   channel the person can get (RN-15-081, D-654).
# Nothing is created during an impersonate (RN-15-007), and the same type, person and
# origin make one notice in 12 hours (RN-15-085).
module Notifications
  # The order of the fallback (RN-15-081, P-15-25).
  FALLBACK_ORDER = %w[whatsapp email push].freeze

  module_function

  # path: where the notice leads, inside the platform. membership: the recipient's
  # membership the notice is about; it gives the company, the brand and the area.
  # dedup_key: the origin, when the subject alone does not tell it (RN-15-085).
  # variant: a key under the type's texts, for a type with more than one wording.
  # params: the variables of the texts in config/locales, under notification_types.
  def notify!(code, user:, path:, membership: nil, company: nil, brand: nil, area: nil, subject: nil, dedup_key: nil, variant: nil,
    **params)
    return if Simulation.active?

    type = NotificationType.find(code)
    company ||= membership.organization if membership&.organization.is_a?(Company)
    brand ||= membership&.subdomain_brand
    channels = reachable_channels(type, user:, membership:, company:, brand:)
    return unless type.in_bell? || channels.any?

    key = dedup_key || (subject && "#{code}/#{subject.class.name}/#{subject.id}")
    notification = Notification.transaction do
      create(type, user:, path:, membership:, company:, brand:, area:, subject:, key:, channels:,
        texts: [ "notification_types", code, variant ].compact.join("."), params:)
    end
    deliver(notification) if notification
    notification
  end

  def create(type, user:, path:, membership:, company:, brand:, area:, subject:, key:, channels:, texts:, params:)
    if key
      # Two runs at the same time wait for each other (RN-15-085).
      Notification.connection.execute(Notification.sanitize_sql([ "SELECT pg_advisory_xact_lock(hashtext(?))", "notifications/#{user.id}/#{key}" ]))
      return if Notification.exists?(recipient_user: user, dedup_key: key, created_at: Notification::DEDUP_WINDOW.ago..)
    end

    notification = Notification.create!(notification_type: type.code, recipient_user: user, recipient_membership: membership,
      company: company,
      brand: brand, area: area || ("panel" if membership), subject: subject, dedup_key: key,
      path: path, mandatory: type.mandatory, urgent: type.urgent, in_bell: type.in_bell?,
      title: I18n.t("#{texts}.title", **params), body: I18n.t("#{texts}.body", **params, default: nil))
    channels.each { |channel| add_delivery(notification, channel) }
    notification
  end

  # The push waits for the quiet hours, unless it is a security notice (RN-15-033). The
  # e-mail of the work notices waits for the daily digest (RN-15-040); a fallback does not.
  def add_delivery(notification, channel, fallback_from: nil)
    state = case channel
    when "email"
      digest_at = DailyDigest.send_at(notification) unless fallback_from
      { destination_masked: NotificationDelivery.mask_email(notification.recipient_user.email), status: digest_at ? "held" : "queued",
        held_until: digest_at }
    when "push"
      held_until = QuietHours.release_at(notification.recipient_membership) unless notification.type.security?
      { status: held_until ? "held" : "queued", held_until: held_until }
    end
    notification.deliveries.create!(channel: channel, fallback_from: fallback_from, **state)
  end

  # The person's choice for the membership, then the company's default, then the catalog's.
  # A mandatory type never ends without an external channel (RN-15-022).
  def channels_for(type, membership:, company:)
    configurable = type.configurable_channels(membership&.roles)
    chosen = membership && NotificationPreference.find_by(membership: membership, notification_type: type.code)&.channels
    chosen ||= company && ActsAsTenant.with_tenant(company) { CompanyNotificationSetting.find_by(notification_type: type.code)&.channels }
    channels = (chosen || configurable) & configurable
    channels.empty? && type.mandatory ? configurable : channels
  end

  # The channels chosen that the person can get. A mandatory notice left with none takes
  # the next one available, even outside the choices (D-409, D-654). A type made for the bell
  # alone stays there: the lockout's e-mail is the access notice (D-607).
  def reachable_channels(type, user:, membership:, company:, brand:)
    channels = channels_for(type, membership:, company:).select { |channel| reachable?(channel, user:, brand:, mandatory: type.mandatory) }
    return channels if channels.any? || !type.mandatory || type.external_channels.empty?

    [ next_channel(user:, brand:, used: []) ].compact
  end

  def next_channel(user:, brand:, used:)
    (FALLBACK_ORDER - used).find { |channel| reachable?(channel, user:, brand:, mandatory: true) }
  end

  def reachable?(channel, user:, brand:, mandatory:)
    case channel
    when "email" then user.email_deliverable?(mandatory: mandatory)
    when "push" then brand.present? && NotificationType.available_channels.include?("push") && PushSubscription.exists?(user: user, brand: brand)
    else false
    end
  end

  # The deliveries leave after the commit, so the job finds them (RN-15-084).
  def deliver(notification)
    notification.deliveries.select(&:queued?).each { |delivery| dispatch(delivery) }
  end

  def dispatch(delivery)
    job = delivery.channel == "push" ? DeliverPushJob : DeliverEmailJob
    ActiveRecord.after_all_transactions_commit { job.perform_later(delivery) }
  end
end
