module SensitiveDataHelper
  # reveal_sensitive(user, :cpf, as: :cpf). Every sensitive value on a page goes through
  # here (RN-05-001).
  def reveal_sensitive(record, field, as:)
    SensitiveData.reveal(record.public_send(field), as: as)
  end
end
