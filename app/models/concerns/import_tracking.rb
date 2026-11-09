# While a confirmed import line is recorded, every record it creates, changes or deletes goes
# to the line's tracker, side effects included, so the whole import can be undone
# (RN-18-052, D-665). Outside an import there is no tracker and nothing happens.
module ImportTracking
  extend ActiveSupport::Concern

  included do
    after_create { Imports::Tracker.current&.created(self) }
    after_update { Imports::Tracker.current&.updated(self) }
    after_destroy { Imports::Tracker.current&.destroyed(self) }
  end
end
