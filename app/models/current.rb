# Per-request context, reset by Rails after each request.
class Current < ActiveSupport::CurrentAttributes
  # :admin or :panel, from the host (spec 01, RN-01-001).
  attribute :area
  # The brand of the subdomain being accessed (spec 01, RN-01-001).
  attribute :brand
  # Host, protocol and port of the request, for links sent by e-mail.
  attribute :url_options
  # The signed-in person's open session (D-576).
  attribute :user_session
end
