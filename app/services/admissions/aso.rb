module Admissions
  # The admission's ASO (RN-07-060, RN-07-061, D-651). For CLT, the item is required and never
  # skipped. The HR records fit or unfit, with the exam's date, on reviewing the document, in
  # place of the AI until spec 14. An unfit ASO stays valid in the folder, but its item stays
  # open and the admission can't end: the HR cancels or asks for a new exam. The result is
  # health data: encrypted, out of the versions, of the history and of the notices.
  module Aso
    CODE = "aso_admission".freeze

    module_function

    def type
      DocumentType.find_by(code: CODE, company_id: nil)
    end

    # The open CLT admission a document of the type answers, or nil.
    def admission_for(document)
      return unless document.document_type.code == CODE

      Admission.in_status("open").for_profile(document.worker_profile).includes(:employment)
        .find { |admission| admission.employment.clt? }
    end

    def item?(item)
      item.document? && item.instance.admission? && item.config["document_type_id"] == type&.id
    end

    # The CLT's item, never skipped nor removed (P-07-11).
    def required_item?(item)
      item?(item) && item.instance.employment&.clt? == true
    end

    def admission_of(item)
      Admission.find_by(employment_id: item.instance.subject_id)
    end

    def record(admission, result:, exam_on:, by:)
      admission.update!(aso_status: result, aso_exam_on: exam_on)
      Processes::Events.record(admission.process_instance, "aso_reviewed", by: by)
      warn_hr(admission) if result == "unfit"
    end

    # A new exam: the unfit one stays in the document's history (RN-07-061).
    def reassess(admission, by:)
      admission.with_lock do
        next false unless admission.open? && admission.aso_unfit?

        admission.update!(aso_status: nil, aso_exam_on: nil)
        admission.process_instance.items.select { |item| item?(item) && item.open? }.each do |item|
          item.update!(status: "pending", completed_by: nil, completed_at: nil)
        end
        Processes::Events.record(admission.process_instance, "aso_reassessment", by: by)
        true
      end
    end

    # Only that the admission needs attention, never the result (RN-15-005, D-651).
    def warn_hr(admission)
      instance = admission.process_instance
      Processes::HrScope.new(admission.company).memberships_for(unit_id: instance.unit_id, kind: instance.kind).each do |membership|
        Notifications.notify!("admission.aso_unfit", user: membership.user, membership: membership, company: admission.company,
          subject: admission, dedup_key: "aso_unfit/#{admission.id}/#{Time.current.to_i}", path: "/admissions/#{admission.id}",
          person: admission.worker_profile.display_name)
      end
    end
    private_class_method :warn_hr
  end
end
