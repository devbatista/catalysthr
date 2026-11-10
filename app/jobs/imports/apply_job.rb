module Imports
  # Records a confirmed import (spec 18, section 8, RN-18-008), on the imports queue.
  class ApplyJob < ApplicationJob
    queue_as :imports

    def perform(import)
      Recording.call(import)
      # The HR administrators hear of the support's import (RN-18-062, D-666).
      AssistedNotice.call(import.reload)
    end
  end
end
