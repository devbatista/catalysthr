module Ai
  # A failed call (RN-14-120, D-383). The code goes to the AiRequest and to the logs; the
  # message never carries the content sent or received (RN-14-131).
  class Error < StandardError
    attr_reader :code

    def initialize(code, message = code)
      @code = code.to_s
      super(message)
    end
  end
end
