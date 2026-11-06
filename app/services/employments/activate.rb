module Employments
  # The employment starts on its date (RN-07-085, D-256, D-653). An admission still open
  # doesn't stop it, because the person is already working, and the HR gets a serious alert.
  # An unfit ASO does: the person shouldn't start, and the cancellation exists only before the
  # activation (RN-07-092). The alert for an eSocial not accepted comes with spec 13 (D-648).
  # Runs again without repeating. Read inside the company.
  module Activate
    module_function

    def call(employment)
      admission = employment.admission
      return hold(admission) if admission&.open? && admission.aso_unfit?

      activated = employment.with_lock do
        next false unless employment.pending?

        employment.update!(status: "active")
      end
      warn_pending(admission) if activated && admission&.open?
      activated
    end

    # Never says why (D-651).
    def hold(admission)
      each_hr(admission) do |membership|
        Notifications.notify!("admission.aso_unfit", user: membership.user, membership: membership, company: admission.company,
          subject: admission, dedup_key: "aso_unfit/held/#{admission.id}/#{admission.employment.today.iso8601}",
          path: "/admissions/#{admission.id}", person: admission.worker_profile.display_name)
      end
      false
    end

    # Only the name and the number of items (RN-15-005).
    def warn_pending(admission)
      pending = admission.process_instance.items.count { |item| item.required && !item.resolved? }
      each_hr(admission) do |membership|
        Notifications.notify!("admission.activated_with_pending", user: membership.user, membership: membership, company: admission.company,
          subject: admission, path: "/admissions/#{admission.id}", person: admission.worker_profile.display_name, count: pending)
      end
    end

    def each_hr(admission, &)
      instance = admission.process_instance
      Processes::HrScope.new(admission.company).memberships_for(unit_id: instance.unit_id, kind: instance.kind).each(&)
    end
    private_class_method :hold, :warn_pending, :each_hr
  end
end
