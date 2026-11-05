module Admissions
  # Moves the start of an admission still pending (RN-07-011, D-648): the employment, its
  # first revision and the dates of the items that count from it (RN-06-027, D-641). The new
  # date is today or later. The eSocial's rectification comes with spec 13 (RN-07-054).
  module Reschedule
    module_function

    def call(admission, started_on:, by:)
      date = parse(started_on)
      employment = admission.employment
      instance = admission.process_instance
      return error(admission, :started_on_invalid) if date.nil? || date < instance.today
      return error(admission, :not_pending) unless admission.open? && employment.pending?

      first = employment.revisions.reason_admission.first
      if employment.revisions.where.not(id: first.id).where(effective_on: ...date).exists?
        return error(admission, :revision_before_start)
      end

      admission.with_lock do
        employment.update!(started_on: date)
        first.update!(effective_on: date)
        Processes::ChangeAnchors.call(instance, { "work_start" => date }, by: by)
      end
      true
    end

    def parse(value)
      value.is_a?(Date) ? value : Date.iso8601(value.to_s)
    rescue Date::Error
      nil
    end

    def error(admission, key)
      admission.errors.add(:base, key)
      false
    end
    private_class_method :parse, :error
  end
end
