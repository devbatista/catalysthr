# The employer's A1 certificate (spec 13, RN-13-020 to RN-13-022, D-075, D-673): the employer's
# own or a proxy's with an electronic power of attorney for the eSocial (RN-13-021), sealed with
# the A1's KMS key (Certificates::Vault). One active per company; a new one replaces it, and
# the replaced or removed one keeps only who held it, the validity and who sent it, without the
# file or the password (D-673). The same certificate signs the eSocial and the time receipts and
# AFD (D-319).
class EmployerCertificate < ApplicationRecord
  STATUSES = %w[active replaced removed].freeze
  OWNER_KINDS = %w[employer proxy].freeze
  # The notices before it expires (RN-13-022, P-13-07).
  ALERT_DAYS = [ 30, 15, 5 ].freeze
  SEALED = %i[sealed_key sealed_pfx sealed_password].freeze

  audited secret: SEALED

  acts_as_tenant :company

  belongs_to :uploaded_by, class_name: "User"
  belongs_to :removed_by, class_name: "User", optional: true

  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :owner_kind, inclusion: { in: OWNER_KINDS }

  def days_left(today = Date.current) = (valid_to.to_date - today).to_i
  def expired?(at = Time.current) = valid_to <= at

  # The holder's document as shown: a CNPJ or a CPF.
  def formatted_holder_document
    document = holder_document.to_s
    if document.length == 14
      document.sub(/\A(.{2})(.{3})(.{3})(.{4})(.{2})\z/, '\1.\2.\3/\4-\5')
    else
      document.sub(/\A(.{3})(.{3})(.{3})(.{2})\z/, '\1.\2.\3-\4')
    end
  end

  # Leaves the record and forgets the file, the password and the data key (D-673).
  def retire!(status, by: nil)
    attributes = SEALED.index_with(nil).merge(status: status)
    attributes.merge!(status == "removed" ? { removed_at: Time.current, removed_by: by } : { replaced_at: Time.current })
    update!(attributes)
  end
end
