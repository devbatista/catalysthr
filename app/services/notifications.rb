# Creates the notices of the catalog (spec 15). The other specs say when a notice is born;
# this module says how it reaches the person (section 1):
# - the bell, when the type has the "system" channel (D-608);
# - an e-mail delivery, when the type has it and the person has an e-mail (RN-15-023).
#   The preferences come in block 15b, and WhatsApp and push in phase 2 (D-607).
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
    email = type.external_channels.include?("email") && user.email.present?
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
      company: company || (membership.organization if membership&.organization.is_a?(Company)),
      brand: brand || membership&.subdomain_brand, area: area || ("panel" if membership), subject: subject, dedup_key: key,
      path: path, mandatory: type.mandatory, urgent: type.urgent, in_bell: type.in_bell?,
      title: I18n.t("#{texts}.title", **params), body: I18n.t("#{texts}.body", **params, default: nil))
    notification.deliveries.create!(channel: "email", destination_masked: NotificationDelivery.mask_email(user.email)) if email
    notification
  end

  # The deliveries leave after the commit, so the job finds them (RN-15-084).
  def deliver(notification)
    deliveries = notification.deliveries.to_a
    ActiveRecord.after_all_transactions_commit do
      deliveries.each { |delivery| DeliverEmailJob.perform_later(delivery) }
    end
  end
end
