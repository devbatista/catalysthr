module AccountingFirms
  # The company's HR administrator registers the accounting firm or links one that
  # already exists (RN-02-070, D-171). A new firm is linked at once, and its first
  # administrator is invited (RN-02-071, D-588). An existing one gets a pending request,
  # which its administrators accept or refuse (P-02-29, D-590). A company has at most one
  # pending or active link (D-589).
  class Link
    Result = Data.define(:link, :invitation)

    def self.call(**)
      new(**).call
    end

    # admin: name, cpf, email, mobile_phone and channels of the first administrator.
    def initialize(company:, name:, cnpj:, admin:, by:)
      @company = company
      @firm_attributes = { name: name, cnpj: cnpj }
      @admin = admin
      @by = by
    end

    def call
      result = AccountingFirmCompany.transaction do
        # Locks the company, so two requests at once cannot both link a firm.
        @company.lock!
        firm = AccountingFirm.find_by(cnpj: Cnpj.normalize(@firm_attributes[:cnpj].to_s))
        firm ? request(firm) : register
      end
      after_commit(result)
      result
    end

    private

    def request(firm)
      link = AccountingFirmCompany.create!(accounting_firm: firm, company: @company, status: "pending", linked_by: @by)
      Result.new(link, nil)
    end

    def register
      firm = AccountingFirm.create!(@firm_attributes)
      link = AccountingFirmCompany.create!(accounting_firm: firm, company: @company, status: "active", linked_by: @by,
        accepted_at: Time.current)
      invitation = Invitations::Create.new(
        organization: firm, roles: %w[firm_admin], channels: @admin[:channels], invited_by: @by, brand: @company.subdomain_brand,
        **@admin.slice(:name, :cpf, :email, :mobile_phone)
      ).issue
      Result.new(link, invitation)
    end

    def after_commit(result)
      link = result.link
      AccessEvent.record!(kind: "admin", action: link.pending? ? "accounting_firm_link_requested" : "accounting_firm_linked",
        user: @by, subject: link, company: @company)
      if result.invitation
        Invitations.deliver(result.invitation)
      else
        link.accounting_firm.memberships.active.with_role("firm_admin").includes(:user).find_each do |membership|
          AccountingFirmMailer.link_requested(link, membership.user).deliver_later if membership.user.email.present?
        end
      end
    end
  end
end
