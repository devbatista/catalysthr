module Processes
  # Writes the process's history (RN-06-051, D-641). details: what the screen needs to
  # tell the change, never sensitive data.
  module Events
    module_function

    def record(instance, action, by:, item: nil, **details)
      instance.events.create!(action: action, actor: by, item: item, details: details.compact)
    end
  end
end
