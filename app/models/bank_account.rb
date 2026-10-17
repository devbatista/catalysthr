# Where the person is paid (RN-04-044, D-208): a bank account (bank, branch, number and
# type) or a PIX key with its type. One active account is the primary; a new primary
# ends the previous one, and accounts are never deleted (D-604, CA-04-008). The owner's
# CPF must be the person's, which the HR declares until the proof comes with the
# documents folder (P-04-17, spec 08). The number and the key are sensitive (D-086).
class BankAccount < ApplicationRecord
  ACCOUNT_TYPES = %w[checking savings salary].freeze
  PIX_KEY_TYPES = %w[cpf email phone random].freeze
  STATUSES = %w[active ended].freeze

  audited sensitive: %i[account_number pix_key]

  acts_as_tenant :company

  belongs_to :worker_profile
  belongs_to :declared_by, class_name: "User"

  encrypts :account_number, :pix_key

  enum :account_type, ACCOUNT_TYPES.index_by(&:itself), validate: { allow_nil: true }, prefix: true
  enum :pix_key_type, PIX_KEY_TYPES.index_by(&:itself), validate: { allow_nil: true }, prefix: :pix
  enum :status, STATUSES.index_by(&:itself), validate: true

  normalizes :bank_code, :branch, with: ->(value) { value.to_s.gsub(/\D/, "").presence }
  normalizes :account_number, with: ->(number) { number.to_s.gsub(/[^0-9Xx]/, "").upcase.presence }
  normalizes :pix_key, with: ->(key) { key.to_s.strip.presence }

  scope :ordered, -> { order(Arel.sql("status = 'ended'"), primary: :desc, created_at: :desc) }

  before_validation :normalize_pix_key

  validates :declared_at, presence: true
  validates :ended_on, presence: true, if: :ended?
  validate :account_or_pix
  validate :pix_key_format

  def audit_company_id
    company_id
  end

  def pix?
    pix_key_type.present?
  end

  private

  def account_or_pix
    bank = [ bank_code, branch, account_number, account_type ]
    if pix?
      errors.add(:base, :account_and_pix) if bank.any?(&:present?)
    elsif bank.any?(&:blank?)
      errors.add(:base, :incomplete)
    else
      errors.add(:bank_code, :invalid) unless bank_code.match?(/\A\d{3}\z/)
      errors.add(:branch, :invalid) unless branch.match?(/\A\d{1,5}\z/)
      errors.add(:account_number, :invalid) unless account_number.match?(/\A[0-9X]{2,20}\z/)
    end
  end

  def normalize_pix_key
    case pix_key_type
    when "cpf", "phone" then self.pix_key = pix_key.to_s.gsub(/\D/, "").presence
    when "email", "random" then self.pix_key = pix_key.to_s.strip.downcase.presence
    end
  end

  def pix_key_format
    return unless pix?

    valid = case pix_key_type
    when "cpf" then Cpf.valid?(pix_key)
    when "email" then pix_key.to_s.match?(URI::MailTo::EMAIL_REGEXP)
    when "phone" then pix_key.to_s.match?(/\A\d{10,13}\z/)
    when "random" then pix_key.to_s.match?(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
    end
    errors.add(:pix_key, :invalid) unless valid
  end
end
