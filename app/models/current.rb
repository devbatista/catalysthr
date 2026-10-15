# Per-request context, reset by Rails after each request.
class Current < ActiveSupport::CurrentAttributes
  # :admin or :panel, from the host (spec 01, RN-01-001).
  attribute :area
  # The brand of the subdomain being accessed (spec 01, RN-01-001).
  attribute :brand
  # The company chosen after sign-in, the tenant of the request (RN-01-004, RN-01-005).
  attribute :company
  # Host, protocol and port of the request, for links sent by e-mail.
  attribute :url_options
  # The signed-in person's open session (D-576).
  attribute :user_session
  # Request data for the audit (spec 05, RN-05-010, RN-05-020).
  attribute :ip, :user_agent, :request_id
end
