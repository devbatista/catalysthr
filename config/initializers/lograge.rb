# One JSON line per request, without personal data (D-510, RN-20-072).
# Each line carries the request id, the signed-in user's id and, during an impersonate,
# who is seeing; the company id is
# added with the current company (spec 01, RN-01-005).
Rails.application.configure do
  config.lograge.enabled = Rails.env.production?
  config.lograge.formatter = Lograge::Formatters::Json.new
  config.lograge.custom_options = lambda do |event|
    { request_id: event.payload[:request_id], time: Time.current.utc.iso8601 }
  end
  config.lograge.custom_payload do |controller|
    # During an impersonate, the user seen and who is seeing (RN-02-088).
    { request_id: controller.request.request_id, user_id: controller.try(:current_user)&.id,
      impersonator_id: Current.impersonation&.impersonator_id }.compact
  end
end
