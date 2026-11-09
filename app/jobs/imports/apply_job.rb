module Imports
  # Records a confirmed import (spec 18, section 8, RN-18-008), on the imports queue.
  class ApplyJob < ApplicationJob
    queue_as :imports

    def perform(import)
      Recording.call(import)
    end
  end
end
