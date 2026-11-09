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
  # The running impersonate session, if any (RN-02-080), and whether this request's
  # writes are being simulated (RN-02-084).
  attribute :impersonation, :simulation
  # The support's running entry into a direct company, if any (D-581).
  attribute :support_access
  # What a confirmed import line changes, recorded to undo it (Imports::Tracker), and
  # whether an import is being undone (RN-18-052, D-665).
  attribute :import_tracker, :import_undo
end
