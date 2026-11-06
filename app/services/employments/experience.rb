module Employments
  # The CLT's experience contract (RN-07-100 to RN-07-102, D-648, D-653): the HR extends it,
  # once and up to 90 days, or confirms it; with nothing recorded, the period's end decides.
  # Each call locks the employment, so running again changes nothing. Read inside the company.
  module Experience
    module_function

    STARTED = %w[active on_leave].freeze

    # "Prorrogar": the days already informed, or the ones given now (CLT art. 451).
    def extend(employment, days:, by:)
      done = employment.with_lock do
        next error(employment, :experience_not_extendable) unless employment.experience_extendable?

        days = employment.experience_extension_days || days
        next error(employment, :experience_not_extendable) if days.to_i < 1

        employment.update(details: employment.details.merge("experience_status" => "extended",
          "experience_extension_days" => days.to_i, "experience_alerted_on" => nil, "experience_resolved_by" => by.name))
      end
      record(employment, "experience_extended", by) if done
      done
    end

    # "Efetivar": the contract goes on with no end date (RN-07-101).
    def confirm(employment, by:)
      done = employment.with_lock do
        next error(employment, :experience_closed) unless employment.experience_decidable?

        indefinite!(employment, by: by)
        true
      end
      record(employment, "experience_confirmed", by) if done
      done
    end

    # What the day brings to one employment (RN-07-101, RN-07-102).
    def check(employment)
      run_out(employment)
      warn_ending(employment) if employment.experience_open? && due_for_notice?(employment)
    end

    def indefinite!(employment, by: nil)
      employment.update!(details: employment.details.except("contract_end_on").merge("experience_status" => "indefinite",
        "contract_term" => "indefinite", "experience_resolved_on" => employment.today.iso8601, "experience_resolved_by" => by&.name))
    end

    # After the period's last day: the extension already in the contract starts by itself;
    # without it the contract is indefinite, which is the legal effect (D-648).
    def run_out(employment)
      variant = employment.with_lock do
        next unless employment.experience_open? && employment.experience_ends_on < employment.today

        if employment.experience_first_period? && employment.experience_extension_days
          employment.update!(details: employment.details.merge("experience_status" => "extended", "experience_alerted_on" => nil))
          "extended"
        else
          indefinite!(employment)
          "indefinite"
        end
      end
      tell_hr(employment, variant) if variant
    end

    def due_for_notice?(employment)
      ends_on = employment.experience_ends_on
      employment.detail(:experience_alerted_on) != ends_on.iso8601 &&
        employment.today >= ends_on - employment.company.experience_alert_days
    end

    # Only the name and the date (RN-15-005). The HR opens the record; the manager follows
    # it in "Minha equipe" (D-653).
    def warn_ending(employment)
      ends_on = employment.experience_ends_on
      revision = employment.effective_revision
      hr = hr_of(employment, revision)
      managers = Department.find_by(id: revision&.department_id)&.managers&.select { |person| person.status.in?(Membership::ACCESS_STATUSES) }.to_a
      (hr | managers).each do |membership|
        notify(employment, membership, nil, hr.include?(membership) ? record_path(employment) : "/portal/team", ends_on)
      end
      employment.update!(details: employment.details.merge("experience_alerted_on" => ends_on.iso8601))
    end

    def tell_hr(employment, variant)
      hr_of(employment, employment.effective_revision).each do |membership|
        notify(employment, membership, variant, record_path(employment), employment.experience_ends_on)
      end
    end

    def hr_of(employment, revision)
      Processes::HrScope.new(employment.company).memberships_for(unit_id: revision&.unit_id, kind: "admission")
    end

    def notify(employment, membership, variant, path, date)
      Notifications.notify!("employments.probation_ending", user: membership.user, membership: membership, company: employment.company,
        subject: employment, variant: variant, dedup_key: "probation/#{employment.id}/#{variant}/#{date.iso8601}", path: path,
        person: employment.worker_profile.display_name, date: I18n.l(date))
    end

    def record_path(employment)
      "/employees/#{employment.worker_profile_id}"
    end

    def record(employment, action, by)
      AccessEvent.record!(kind: "admin", action: action, user: by, subject: employment)
    end

    def error(employment, key)
      employment.errors.add(:base, key)
      false
    end
    private_class_method :run_out, :due_for_notice?, :warn_ending, :tell_hr, :hr_of, :notify, :record_path, :record, :error
  end
end
