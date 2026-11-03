module Documents
  # The acknowledgment of a document (RN-08-051 to RN-08-053, D-279): the employee confirms
  # "Li e estou ciente" in the portal (spec 16), which keeps the date, the time, the IP, the
  # browser and the file's hash; without it by the date, the HR records the refusal, with a
  # note and up to two witnesses (name and CPF), as on paper. Locked meanwhile, so it is
  # recorded once. Returns false with the errors on the acknowledgment.
  class Acknowledge
    def initialize(acknowledgment)
      @acknowledgment = acknowledgment
    end

    def confirm(by:, ip:, user_agent:, comment: nil)
      return error(:not_yours) unless by == @acknowledgment.worker_profile.user
      return error(:not_ready) unless @acknowledgment.version.approved? && @acknowledgment.version.readable?

      record do
        @acknowledgment.update(status: "acknowledged", acknowledged_at: Time.current, ip: ip, user_agent: user_agent.to_s.first(500),
          comment: comment, sha256: @acknowledgment.version.sha256)
      end
    end

    def refuse(by:, note:, witnesses: [])
      return error(:not_overdue) unless @acknowledgment.overdue?

      witnesses = Array(witnesses).map { |witness| witness.to_h.stringify_keys.slice("name", "cpf") }
        .map { |witness| { "name" => witness["name"].to_s.squish, "cpf" => Cpf.normalize(witness["cpf"].to_s) } }
        .reject { |witness| witness.values.all?(&:blank?) }
      return error(:too_many_witnesses, count: Acknowledgment::MAX_WITNESSES) if witnesses.size > Acknowledgment::MAX_WITNESSES
      return error(:witness_invalid) unless witnesses.all? { |witness| witness["name"].present? && Cpf.valid?(witness["cpf"]) }

      record do
        @acknowledgment.update(status: "refused", refused_note: note, witnesses: witnesses, recorded_by: by, recorded_at: Time.current)
      end
    end

    private

    def record
      @acknowledgment.with_lock do
        next error(:not_awaiting) unless @acknowledgment.awaiting?

        yield || raise(ActiveRecord::Rollback)
      end || false
    end

    def error(key, **options)
      @acknowledgment.errors.add(:base, key, **options)
      false
    end
  end
end
