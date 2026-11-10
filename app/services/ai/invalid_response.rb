module Ai
  # An invalid request (4xx), an answer outside the schema, a refusal or an answer cut by the
  # token limit (RN-14-120): one new try, then it fails. A refusal is not sent again to another
  # model, which could be outside the zero data retention (D-670).
  class InvalidResponse < Error; end
end
