module Imports
  # "Liberar acesso de todos" of an import of admissions (P-07-06, RN-07-020, D-668): the
  # admissions the import created that are still open and not released. The invitation goes
  # only by e-mail; who has no e-mail is left for the admission's screen, with the link or the
  # QR code (D-668).
  class AdmissionsRelease
    def initialize(import)
      @import = import
    end

    def admissions
      return Admission.none unless @import.kind == "admissions"

      Admission.awaiting_release.where(id: @import.rows.status_imported.where(record_type: "Admission").select(:record_id))
        .includes(employment: { worker_profile: { membership: :user } })
    end

    def with_email = admissions.to_a.select { |admission| email(admission).present? }
    def without_email = admissions.to_a.reject { |admission| email(admission).present? }

    def releasable?
      @import.status.in?(%w[completed completed_with_errors]) && with_email.any?
    end

    # Releases each one the person may release; returns how many went out and the names of the
    # ones that could not.
    def call(by:)
      ability = Ability.new(by, area: :panel, company: @import.company)
      released = 0
      failed = []
      with_email.each do |admission|
        next unless ability.can?(:release, admission)

        ::Admissions::ReleaseAccess.call(admission, channels: %w[email], by: by)
        released += 1
      rescue ActiveRecord::RecordInvalid
        failed << admission.worker_profile.user.name
      end
      [ released, failed ]
    end

    private

    def email(admission)
      admission.worker_profile.membership.user.email
    end
  end
end
