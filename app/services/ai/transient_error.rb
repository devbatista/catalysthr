module Ai
  # Rate limit, overload, server error, time out or connection (RN-14-120): up to 3 new tries,
  # after 1, 5 and 15 minutes.
  class TransientError < Error; end
end
