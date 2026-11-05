module Admissions
  # Changes the model before the invitation goes out (RN-07-013, D-648): the old process is
  # cancelled with its history and a new one starts. The documents stay in the folder: a
  # document item whose type already has an approved version is born resolved, and a version
  # still in review keeps answering the new item. Everything else starts over.
  module ChangeTemplate
    module_function

    def call(admission, template:, by:, starter:)
      admission.with_lock do
        next false if admission.released? || !admission.open?

        previous = admission.process_instance
        next true if previous.process_template_id == template.id

        Processes::Complete.cancel(previous, by: by, reason: I18n.t("admissions.template_changed"))
        instance = Admissions.start_process(template: template, employment: admission.employment, by: by, starter: starter)
        carry_documents(previous, instance, by: by)
        admission.update!(process_instance: instance)
        true
      end
    end

    def carry_documents(previous, instance, by:)
      profile_id = instance.employment.worker_profile_id
      instance.items.select(&:document?).each do |item|
        documents = Document.kept.where(worker_profile_id: profile_id, document_type_id: item.config["document_type_id"]).to_a
        carried = documents.find { |document| document.process_item&.process_instance_id == previous.id }
        carried&.update!(source_ref: item)
        approved = documents.find(&:current_version_id)
        if approved
          approve(item, approved, by: by)
        elsif carried
          Processes::DocumentItem.sync(carried, by: by)
        end
      end
    end

    def approve(item, document, by:)
      item.update!(status: "approved", completed_by: by, completed_at: Time.current, result: { "document_id" => document.id })
      Processes::Events.record(item.instance, "document_approved", by: by, item: item, title: item.title)
      Processes::UnblockItemsJob.perform_later(item)
    end
    private_class_method :carry_documents, :approve
  end
end
