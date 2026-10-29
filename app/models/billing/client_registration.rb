module Billing
  # The registration of a partner or a direct company by the CatalystHR team (RN-19-081,
  # D-484, D-613): the organization, its brand and subdomain, the contract with the plan's
  # current version, the modules and add-ons, a trial or a contract starting today, and
  # the invitation of the first administrator, who becomes the responsible (RN-19-044).
  # A partner under contract starts on the pre-activation fee (RN-19-035, D-612). A
  # contract gets the first cycle's invoice at once, due that day (D-619).
  class ClientRegistration
    include ActiveModel::Model
    include ActiveModel::Attributes

    KINDS = %w[partner direct].freeze
    MODES = %w[trial contract].freeze

    attribute :kind, :string
    attribute :mode, :string, default: "trial"
    attribute :legal_name, :string
    attribute :commercial_name, :string
    attribute :cnpj, :string
    attribute :slug, :string
    attribute :plan_id, :string
    attribute :modules, default: -> { [] }
    attribute :add_on_codes, default: -> { [] }
    attribute :admin_name, :string
    attribute :admin_cpf, :string
    attribute :admin_email, :string
    # The contract's billing address, the NFS-e's customer at Asaas (RN-19-103, D-635).
    BillingAccount::ADDRESS_FIELDS.each { |field| attribute field, :string }

    validates :kind, inclusion: { in: KINDS }
    validates(*BillingAccount::REQUIRED_ADDRESS_FIELDS, presence: true)
    validates :mode, inclusion: { in: MODES }
    validates :legal_name, :commercial_name, :slug, :admin_name, :admin_email, presence: true
    validates :cnpj, presence: true, cnpj: true
    validates :admin_cpf, presence: true, cpf: true
    validates :admin_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
    validate :plan_on_sale
    validate :known_items
    validate :pre_activation_price_defined

    attr_reader :billing_account

    # The CPF already had an account: the invitation goes to that person, whose data stay
    # as they are (RN-02-010, D-209).
    def existing_person?
      @existing_person
    end

    def partner?
      kind == "partner"
    end

    def plan
      @plan ||= Plan.active.public_plans.where(kind: kind).find_by(id: plan_id) if plan_id
    end

    def plan_version
      plan&.version_on
    end

    def selected_modules
      Array(modules).compact_blank & PlanModule::MODULES
    end

    def selected_add_on_prices
      Array(add_on_codes).compact_blank.map { |code| AddOn.active.find_by(code: code)&.price_on }
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
      owner = partner? ? create_partner : create_direct_company
      brand = Brand.create!(owner: owner, commercial_name: commercial_name)
      brand.subdomains.create!(slug: slug)

      invitation = Invitations::Create.new(organization: owner, roles: [ partner? ? "partner_admin" : "hr_admin" ], channels: %w[email],
        invited_by: by, name: admin_name, cpf: admin_cpf, email: admin_email).issue

      today = Date.current
      @billing_account = BillingAccount.create!(owner: owner, responsible_user: invitation.membership.user,
        cycle_day: BillingAccount.cycle_day_for(today), **billing_address)
      subscription = Subscription.create!(billing_account: @billing_account, plan_version: plan_version, created_by: by,
        status: mode == "trial" ? "trialing" : "active", started_on: today,
        trial_ends_on: (today + Subscription::TRIAL_DAYS if mode == "trial"),
        pre_activation_price: (PreActivationPrice.on(today) if partner? && mode == "contract"),
        activated_on: (today if !partner? && mode == "contract"))
      selected_modules.each { |code| subscription.items.create!(kind: "module", module: code, starts_on: today) }
      selected_add_on_prices.each { |price| subscription.items.create!(kind: "add_on", add_on_price: price, starts_on: today) }
      # The first cycle's invoice, due today (RN-19-033, D-619).
      Invoicing.issue_due(subscription, today, lead: 0) if mode == "contract"
      invitation
    end

    def billing_address
      BillingAccount::ADDRESS_FIELDS.index_with { |field| public_send(field) }
    end

    def create_partner
      Partner.create!(name: commercial_name, legal_name: legal_name, cnpj: cnpj)
    end

    def create_direct_company
      Company.create_with_cnpj!(cnpj: cnpj, name: commercial_name, legal_name: legal_name)
    end

    def plan_on_sale
      return if kind.blank?

      if plan.nil?
        errors.add(:plan_id, :not_on_sale)
      elsif plan_version.nil?
        errors.add(:plan_id, :not_started)
      end
    end

    def known_items
      errors.add(:modules, :inclusion) if (Array(modules).compact_blank - PlanModule::MODULES).any?
      errors.add(:add_on_codes, :without_price) if selected_add_on_prices.any?(&:nil?)
    end

    # The partner's contract starts on the pre-activation fee (D-612).
    def pre_activation_price_defined
      errors.add(:base, :without_pre_activation_price) if partner? && mode == "contract" && PreActivationPrice.on.nil?
    end
  end
end
