module SensitiveDataHelper
  # reveal_sensitive(user, :cpf, as: :cpf). Every sensitive value on a page goes through
  # here (RN-05-001).
  def reveal_sensitive(record, field, as:)
    SensitiveData.reveal(record.public_send(field), as: as)
  end

  # A value of a section shown only after the password (RN-02-052, D-086): hidden until
  # the section is revealed, masked during an impersonate (RN-02-087), and otherwise
  # shown and recorded as a sensitive read, once per record and field in the request
  # (RN-05-020). A value may be given when the field is not a plain attribute.
  def reveal_confirmed(record, field, as:, section:, value: record.public_send(field))
    return SensitiveData::HIDDEN unless revealed_sections.include?(section.to_s)
    return value if value.blank? && value != 0
    return SensitiveData.mask(value, as: as) if Current.impersonation

    @sensitive_reads ||= Set.new
    if @sensitive_reads.add?([ record.class.name, record.id, field.to_s ])
      AccessEvent.record!(kind: "sensitive_read", action: "view", user: current_user, subject: record, field: field.to_s)
    end
    as == :money ? "R$ #{MoneyCents.format(value)}" : value
  end
end
