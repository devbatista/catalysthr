module Billing
  # A client company registered by the partner's administrator (P-03-14, D-616): the
  # company in the portfolio, the partner's contracted modules turned on or off for it
  # (RN-19-012), and the invitation of its first HR administrator. The company is billed
  # through the partner and follows the partner's trial (RN-19-001, RN-19-030).
  class PortfolioCompanyRegistration
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :legal_name, :string
    attribute :commercial_name, :string
    attribute :cnpj, :string
    attribute :modules, default: -> { [] }
    attribute :admin_name, :string
    attribute :admin_cpf, :string
    attribute :admin_email, :string

    attr_accessor :partner
    attr_reader :company

    validates :legal_name, :commercial_name, :admin_name, :admin_email, presence: true
    validates :cnpj, presence: true, cnpj: true
    validates :admin_cpf, presence: true, cpf: true
    validates :admin_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
    validate :contract_in_force
    validate :contracted_modules_only

    # The CPF already had an account: the invitation goes to that person, whose data stay
    # as they are (RN-02-010, D-209).
    def existing_person?
      @existing_person
    end

    def contract?
      subscription = partner&.subscription
      subscription.present? && !subscription.closed?
    end

    # The partner's modules, the only ones the company can have (RN-19-012).
    def contracted_modules
      partner&.contracted_modules || []
    end

    def selected_modules
      Array(modules).compact_blank & PlanModule::MODULES
    end

    # Saves everything or nothing, then sends the invitation. Errors of the records end up
    # here, to be shown on the form.
    def save(by:)
      return false unless valid?

      invitation = ActiveRecord::Base.transaction { register(by) }
      Invitations.deliver(invitation)
      true
    rescue ActiveRecord::RecordInvalid => error
      error.record.errors.each { |record_error| errors.add(:base, record_error.full_message) }
      false
    end

    private

    def register(by)
      @existing_person = User.exists?(cpf: Cpf.normalize(admin_cpf))
      @company = Company.create_with_cnpj!(cnpj: cnpj, name: commercial_name, legal_name: legal_name, partner: partner)
      now = Time.current
      contracted_modules.each do |code|
        company.module_settings.create!(module: code, enabled: selected_modules.include?(code), changed_by: by, changed_at: now)
      end
      Invitations::Create.new(organization: company, roles: %w[hr_admin], channels: %w[email], invited_by: by,
        name: admin_name, cpf: admin_cpf, email: admin_email).issue
    end

    def contract_in_force
      errors.add(:base, :without_contract) unless contract?
    end

    def contracted_modules_only
      errors.add(:modules, :not_contracted) if (Array(modules).compact_blank - contracted_modules).any?
    end
  end
end
