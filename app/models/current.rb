# Per-request context, reset by Rails after each request.
class Current < ActiveSupport::CurrentAttributes
  # The brand of the subdomain being accessed (spec 01, RN-01-001).
  attribute :brand
end
