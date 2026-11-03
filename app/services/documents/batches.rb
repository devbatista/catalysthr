module Documents
  # The end of a batch's files not distributed (RN-08-062): deleted when the batch expires,
  # or, the discarded ones, when the batch is fully distributed.
  module Batches
    module_function

    def expire(batch)
      batch.with_lock do
        purge(batch.items.where.not(status: "distributed"))
        batch.update!(status: "expired")
      end
    end

    def purge(items)
      items.includes(file_attachment: :blob).find_each { |item| item.file.purge_later if item.file.attached? }
    end
  end
end
