module Admissions
  # Cancels an admission before the employment starts (RN-07-090 to RN-07-092, D-257, D-651):
  # the employment, the process and an onboarding under way end, the PDFs generated go, and
  # the access goes, unless the person has other employments or roles in the company. Data
  # and documents stay for the retention of who wasn't hired (spec 05). After the activation,
  # the way out is the termination (spec 09). The S-3000 comes with spec 13.
  module Cancellation
    module_function

    def call(admission, reason:, note:, by:)
      employment = admission.employment
      return error(admission, :already_started) unless employment.pending?
      return error(admission, :reason_blank) unless reason.in?(Admission::CANCEL_REASONS)
      return error(admission, :note_blank) if reason == "other" && note.to_s.strip.empty?

      admission.with_lock do
        # The process's history never tells an unfit ASO (D-651).
        label = I18n.t("admissions.cancel_reasons.#{reason == "aso_unfit" ? "generic" : reason}")
        employment.update!(status: "cancelled")
        Processes::Complete.cancel(admission.process_instance, by: by, reason: label, completed_too: true)
        ProcessInstance.open.where(subject: employment, kind: "onboarding").find_each do |instance|
          Processes::Complete.cancel(instance, by: by, reason: label)
        end
        admission.update!(cancelled_at: Time.current, cancel_reason: reason, cancel_note: note.to_s.strip.presence)
        Admissions.delete_generated(employment)
        release_access(employment, by)
      end
      AccessEvent.record!(kind: "admin", action: "admission_cancelled", user: by, subject: admission)
      true
    end

    def release_access(employment, by)
      profile = employment.worker_profile
      return if Employment.where(worker_profile_id: profile.id).where.not(status: "cancelled").exists?

      membership = profile.membership
      others = membership.roles - %w[employee]
      if others.any?
        membership.update!(roles: others)
      else
        Memberships::Revoke.call(membership: membership, by: by)
      end
    end

    def error(admission, key)
      admission.errors.add(:base, key)
      false
    end
    private_class_method :release_access, :error
  end
end
