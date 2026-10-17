# A work contract of the person in the company (RN-04-050 to RN-04-055, D-176, D-205). A
# record may have several, at the same time or one after another, each with its own
# registration number, unique among all the company's employments, ended ones included
# (RN-04-052, P-04-18, CA-04-010). The conditions live in the revisions, by date
# (RN-04-060, D-207).
#
# The fields of each kind go in details (RN-04-053, P-04-27). List fields keep the
# system's own values, and the final list is checked against the eSocial layout in
# spec 13 (P-04-15, D-602). A contractor's monthly amount is the revision's salary.
class Employment < ApplicationRecord
  audited

  KINDS = %w[clt intern autonomous owner contractor].freeze
  # The CLT subtypes (RN-04-050).
  CLT_CATEGORIES = %w[standard apprentice temporary intermittent].freeze
  STATUSES = %w[pending active on_leave terminated cancelled].freeze
  # Employments that keep the employee role and count as people of a unit or a
  # department (RN-04-014, RN-04-025, RN-04-055).
  OPEN_STATUSES = %w[pending active on_leave].freeze
  REGISTRATION_FORMAT = %r{\A[0-9A-Za-z./-]{1,30}\z}

  OPTIONS = {
    "admission_type" => %w[regular group_transfer consortium_transfer succession_transfer domestic_transfer cpf_change],
    "admission_indicator" => %w[normal tax_audit court_decision],
    "labor_regime" => %w[clt statutory],
    "social_security_regime" => %w[rgps rpps foreign],
    "activity_nature" => %w[urban rural],
    "contract_term" => %w[indefinite fixed],
    "internship_nature" => %w[mandatory non_mandatory],
    "internship_level" => %w[elementary high_school vocational higher special],
    "payment_method" => %w[bank_transfer pix boleto other]
  }.freeze
  # The details of each kind (RN-04-053).
  DETAILS = {
    "clt" => %w[admission_type admission_indicator labor_regime social_security_regime activity_nature fgts_option_on
      contract_term contract_end_on assurance_clause union_cnpj union_base_month],
    "intern" => %w[internship_nature internship_level internship_area insurance_policy expected_end_on school_name
      school_cnpj agent_name agent_cnpj supervisor_name supervisor_cpf],
    "autonomous" => [],
    "owner" => [],
    "contractor" => %w[contract_end_on contract_object contractor_cnpj contractor_legal_name payment_method]
  }.freeze
  DATE_DETAILS = %w[fgts_option_on contract_end_on expected_end_on].freeze
  CNPJ_DETAILS = %w[union_cnpj school_cnpj agent_cnpj contractor_cnpj].freeze

  acts_as_tenant :company

  belongs_to :worker_profile
  has_many :revisions, -> { order(:effective_on, :id) }, class_name: "EmploymentRevision", inverse_of: :employment,
    dependent: :restrict_with_error

  enum :kind, KINDS.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true

  normalizes :registration_number, with: ->(number) { number.to_s.strip.presence }

  scope :open, -> { where(status: OPEN_STATUSES) }

  before_validation :keep_details_of_kind

  validates :registration_number, presence: true, format: { with: REGISTRATION_FORMAT, allow_nil: true },
    uniqueness: { scope: :company_id }
  validates :started_on, presence: true
  validates :category, inclusion: { in: CLT_CATEGORIES }, if: :clt?
  validates :category, absence: true, unless: :clt?
  validates :ended_on, :termination_reason, presence: true, if: :terminated?
  validate :details_valid
  validate :same_company

  def audit_company_id
    company_id
  end

  def open?
    status.in?(OPEN_STATUSES)
  end

  def detail(key)
    details[key.to_s]
  end

  # Errors of a detail are reported as details_<key>.
  def read_attribute_for_validation(attribute)
    attribute.to_s.start_with?("details_") ? detail(attribute.to_s.delete_prefix("details_")) : super
  end

  # The revision in force on the date: the latest effective date not after it, and among
  # those of the same date the last registered (RN-04-061, D-603). Before the first
  # one starts, none.
  def revision_on(date)
    revisions.select { |revision| revision.effective_on <= date }.max_by { |revision| [ revision.effective_on, revision.id ] }
  end

  def current_revision
    revision_on(Date.current)
  end

  # The revision that counts now, or, before the employment starts, the first one.
  def effective_revision
    current_revision || revisions.min_by { |revision| [ revision.effective_on, revision.id ] }
  end

  def scheduled_revisions
    revisions.select { |revision| revision.effective_on > Date.current }
  end

  private

  # Only the fields of the kind are kept, typed (P-04-27).
  def keep_details_of_kind
    allowed = DETAILS.fetch(kind.to_s, [])
    self.details = details.to_h.stringify_keys.slice(*allowed).filter_map do |key, value|
      value = value.to_s.strip.presence unless [ true, false ].include?(value)
      value = ActiveModel::Type::Boolean.new.cast(value) if key == "assurance_clause"
      value = value.to_i if key == "union_base_month" && value.present?
      value = Cnpj.normalize(value) if key.in?(CNPJ_DETAILS) && value.present?
      value = Cpf.normalize(value) if key == "supervisor_cpf" && value.present?
      [ key, value ] unless value.nil?
    end.to_h
    self.category = nil unless clt?
  end

  def details_valid
    details.each do |key, value|
      if OPTIONS.key?(key)
        errors.add(:"details_#{key}", :inclusion) unless OPTIONS[key].include?(value)
      elsif key.in?(DATE_DETAILS)
        errors.add(:"details_#{key}", :invalid_date) unless valid_date?(value)
      elsif key.in?(CNPJ_DETAILS)
        errors.add(:"details_#{key}", :invalid_cnpj) unless Cnpj.valid?(value)
      elsif key == "supervisor_cpf"
        errors.add(:details_supervisor_cpf, :invalid_cpf) unless Cpf.valid?(value)
      elsif key == "union_base_month"
        errors.add(:details_union_base_month, :inclusion) unless (1..12).cover?(value)
      end
    end
    if detail(:contract_term) == "fixed" && detail(:contract_end_on).blank?
      errors.add(:details_contract_end_on, :blank)
    end
  end

  def valid_date?(value)
    Date.iso8601(value.to_s)
    true
  rescue Date::Error
    false
  end

  def same_company
    errors.add(:worker_profile, :other_company) if worker_profile && worker_profile.company_id != company_id
  end
end
