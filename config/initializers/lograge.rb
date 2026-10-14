# One JSON line per request, without personal data (D-510, RN-20-072).
# Each line carries the request id; company and user ids are added once
# multi-tenancy and authentication exist (spec 01 and 02).
Rails.application.configure do
  config.lograge.enabled = Rails.env.production?
  config.lograge.formatter = Lograge::Formatters::Json.new
  config.lograge.custom_options = lambda do |event|
    { request_id: event.payload[:request_id], time: Time.current.utc.iso8601 }
  end
  config.lograge.custom_payload do |controller|
    { request_id: controller.request.request_id }
  end
end
