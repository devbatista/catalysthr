# An establishment of the company: headquarters, branch or site, with its own CNPJ, CNO
# or CAEPF, or none, using the headquarters' (RN-04-010 to RN-04-014, D-201). Its time
# zone sets the local time of punches and deadlines (RN-04-013); its position is the
# base of the time clock's geofence, always confirmed by the HR on the map (RN-04-012,
# D-216).
class Unit < ApplicationRecord
  audited

  HEADQUARTERS_NAME = "Matriz"
  REGISTRATION_TYPES = %w[cnpj cno caepf].freeze
  STATUSES = %w[active inactive].freeze
  STATES = %w[AC AL AP AM BA CE DF ES GO MA MT MS MG PA PB PR PE PI RJ RN RS RO RR SC SP SE TO].freeze
  # Time zones in use in Brazil (RN-04-013, P-04-07).
  TIME_ZONES = %w[
    America/Sao_Paulo America/Bahia America/Fortaleza America/Recife America/Belem America/Araguaina
    America/Maceio America/Manaus America/Cuiaba America/Campo_Grande America/Porto_Velho
    America/Boa_Vista America/Rio_Branco America/Noronha
  ].freeze
  POSTAL_CODE_FORMAT = /\A\d{8}\z/

  acts_as_tenant :company
  include StructureCode

  has_many :membership_units, dependent: :destroy

  enum :registration_type, REGISTRATION_TYPES.index_by(&:itself), validate: { allow_nil: true }
  enum :status, STATUSES.index_by(&:itself), validate: true

  normalizes :registration_number, with: ->(number) { number.to_s.gsub(/[^0-9A-Za-z]/, "").upcase.presence }
  normalizes :postal_code, with: ->(code) { code.to_s.gsub(/\D/, "").presence }
  normalizes :state, with: ->(state) { state.to_s.strip.upcase.presence }

  scope :ordered, -> { order(headquarters: :desc, name: :asc) }

  validates :name, presence: true, length: { maximum: 120 }
  validates :time_zone, inclusion: { in: TIME_ZONES }
  validates :postal_code, format: { with: POSTAL_CODE_FORMAT }, allow_nil: true
  validates :state, inclusion: { in: STATES }, allow_nil: true
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
  validates :registration_number, presence: true, if: :registration_type
  validate :registration
  validate :headquarters_stays_active
  validate :empty_before_inactive, if: -> { status_changed? && inactive? }

  def audit_company_id
    company_id
  end

  def positioned?
    latitude.present? && longitude.present?
  end

  # The number used for the unit: its own, or the headquarters' (D-201).
  def effective_registration
    registration_number ? self : company.headquarters
  end

  private

  # A branch's CNPJ has the company's root (RN-04-011, CA-04-001). A person employer has
  # no CNPJ: its units use the CNO or the CAEPF.
  def registration
    return if registration_number.blank? || registration_type.blank?

    case registration_type
    when "cnpj"
      if company&.person?
        errors.add(:registration_type, :cnpj_for_person)
      elsif !Cnpj.valid?(registration_number)
        errors.add(:registration_number, :invalid_cnpj)
      elsif company && registration_number[0, 8] != company.document
        errors.add(:registration_number, :other_root, root: company.formatted_document)
      end
    else
      # The CNO's and the CAEPF's length and check digits are still to be confirmed
      # against the official layout (spec 13); only digits are accepted for now.
      errors.add(:registration_number, :invalid_registration) unless registration_number.match?(/\A\d+\z/)
    end
  end

  # A unit is inactivated only with no open employment in it, now or later (RN-04-014,
  # P-04-08).
  def empty_before_inactive
    errors.add(:status, :open_employments) if EmploymentRevision.placing_open_employments.exists?(unit_id: id)
  end

  # The headquarters is never inactivated (RN-04-010).
  def headquarters_stays_active
    errors.add(:status, :headquarters_inactive) if headquarters? && inactive?
  end
end
