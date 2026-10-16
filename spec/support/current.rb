# Per-request context does not leak from one example to the next (Current is reset by
# Rails after each request, but not after a model or service example).
RSpec.configure do |config|
  config.after { Current.reset }
end
