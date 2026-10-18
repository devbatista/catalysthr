# Creates the notices of the catalog (spec 15). The other specs say when a notice is born;
# this module says how it reaches the person (section 1):
# - the bell, when the type has the "system" channel (D-608);
# - an e-mail delivery, when the person's channels have it (their own choice, then the
#   company's default, then the catalog's, RN-15-020 to RN-15-022) and the e-mail can
#   receive it (RN-15-023, RN-15-083, D-609). WhatsApp and push come in phase 2 (D-607).
# Nothing is created during an impersonate (RN-15-007), and the same type, person and
# origin make one notice in 12 hours (RN-15-085).
module Notifications
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
    email = channels_for(type, membership:, company:).include?("email") && user.email_deliverable?(mandatory: type.mandatory)
    return unless type.in_bell? || email

    key = dedup_key || (subject && "#{code}/#{subject.class.name}/#{subject.id}")
    notification = Notification.transaction do
      create(type, user:, path:, membership:, company:, brand:, area:, subject:, key:, email:,
        texts: [ "notification_types", code, variant ].compact.join("."), params:)
    end
    deliver(notification) if notification
    notification
  end

  def create(type, user:, path:, membership:, company:, brand:, area:, subject:, key:, email:, texts:, params:)
    if key
      # Two runs at the same time wait for each other (RN-15-085).
      Notification.connection.execute(Notification.sanitize_sql([ "SELECT pg_advisory_xact_lock(hashtext(?))", "notifications/#{user.id}/#{key}" ]))
      return if Notification.exists?(recipient_user: user, dedup_key: key, created_at: Notification::DEDUP_WINDOW.ago..)
    end

    notification = Notification.create!(notification_type: type.code, recipient_user: user, recipient_membership: membership,
      company: company,
      brand: brand || membership&.subdomain_brand, area: area || ("panel" if membership), subject: subject, dedup_key: key,
      path: path, mandatory: type.mandatory, urgent: type.urgent, in_bell: type.in_bell?,
      title: I18n.t("#{texts}.title", **params), body: I18n.t("#{texts}.body", **params, default: nil))
    notification.deliveries.create!(channel: "email", destination_masked: NotificationDelivery.mask_email(user.email)) if email
    notification
  end

  # The person's choice for the membership, then the company's default, then the catalog's.
  # A mandatory type never ends without an external channel (RN-15-022).
  def channels_for(type, membership:, company:)
    chosen = membership && NotificationPreference.find_by(membership: membership, notification_type: type.code)&.channels
    chosen ||= company && ActsAsTenant.with_tenant(company) { CompanyNotificationSetting.find_by(notification_type: type.code)&.channels }
    channels = (chosen || type.configurable_channels) & type.configurable_channels
    channels.empty? && type.mandatory ? type.configurable_channels : channels
  end

  # The deliveries leave after the commit, so the job finds them (RN-15-084).
  def deliver(notification)
    deliveries = notification.deliveries.to_a
    ActiveRecord.after_all_transactions_commit do
      deliveries.each { |delivery| DeliverEmailJob.perform_later(delivery) }
    end
  end
end
