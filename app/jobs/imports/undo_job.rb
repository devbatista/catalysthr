module Imports
  # Undoes a whole import (spec 18, section 8, RN-18-052, D-665), on the imports queue. When
  # something blocks, the import goes back to how it was, with the list of what blocks
  # (RN-18-051). Idempotent: an import already undone is left alone.
  class UndoJob < ApplicationJob
    queue_as :imports

    def perform(import, by)
      return unless import.undoing?

      blockers = Undo.new(import, by: by).call
      return if blockers.empty?

      import.update!(status: import.options.fetch("undo_from", "completed"), undo_blockers: blockers)
    end
  end
end
