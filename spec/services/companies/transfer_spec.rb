require "rails_helper"

# Spec 01, RN-01-050 to RN-01-053, D-123 and D-599: moving a company between partners
# and to and from the direct modality.
RSpec.describe Companies::Transfer do
  include ActiveJob::TestHelper

  let(:superadmin) { create(:user, platform_role: "superadmin") }
  let(:aurora) { create(:partner, name: "Aurora Gestão de Pessoas") }
  let(:boreal) { create(:partner, name: "Boreal Consultoria") }
  let(:company) { create(:company, partner: aurora, name: "Padaria Pão Quente") }

  before do
    create(:brand, owner: aurora).subdomains.create!(slug: "aurora")
    create(:brand, owner: boreal, commercial_name: "Boreal RH").subdomains.create!(slug: "boreal")
  end

  def transfer(to:, slug: nil, document: nil, text: "Aceite por e-mail da RH administradora em 15/10/2026")
    described_class.call(company: company, to_partner: to, performed_by: superadmin, authorized_by_text: text,
      document: document, slug: slug)
  end

  describe "from one partner to another (RN-01-051)" do
    it "changes only the partner, keeps the company's memberships and drops the old consultants" do
      hr = create(:membership, organization: company, roles: %w[hr_admin])
      consultant = create(:membership, organization: aurora, roles: %w[consultant])
      consultant.partner_membership_companies.create!(company: company)

      result = transfer(to: boreal)

      expect(result).to be_success
      expect(company.reload).to have_attributes(partner: boreal, name: "Padaria Pão Quente", brand_display_mode: "alongside")
      expect(hr.reload).to be_active
      expect(PartnerMembershipCompany.where(company: company)).to be_empty
      expect(result.transfer).to have_attributes(from_partner: aurora, to_partner: boreal, performed_by: superadmin)
    end

    # The adoption already made the company's copy (P-06-01, D-232): nothing is copied, and
    # the copy stops depending on the old partner, whose own models stay with it (D-639).
    it "keeps the models adopted from the old partner as the company's own (RN-01-053, D-639)" do
      original = SharedProcessTemplate.create!(partner: aurora, kind: "admission", name: "Admissão Aurora", status: "active")
      original.items.create!(position: 1, kind: "task", title: "Boas-vindas", responsible_role: "hr")
      copy = ActsAsTenant.with_tenant(company) { ProcessTemplates::Adopt.call(original, into: company, by: superadmin) }

      transfer(to: boreal)
      original.update!(name: "Admissão Aurora 2027")
      original.items.first.update!(title: "Outro item")

      ActsAsTenant.with_tenant(company) do
        expect(ProcessTemplate.sole).to have_attributes(id: copy.id, name: "Admissão Aurora", source_template_id: original.id)
        expect(ProcessTemplateItem.sole.title).to eq("Boas-vindas")
      end
      expect(SharedProcessTemplate.where(partner: aurora).sole).to eq(original)
    end

    it "keeps the company's own brand and its display mode (D-168)" do
      company.update!(brand_display_mode: "replace")
      create(:brand, owner: company, commercial_name: "Padaria RH")

      transfer(to: boreal)

      expect(company.reload.brand.commercial_name).to eq("Padaria RH")
      expect(company).to be_brand_replace
    end

    it "tells the company's users the new address, once (RN-01-052)" do
      create(:membership, organization: company, roles: %w[hr_admin], user: create(:user, email: "rh@padaria.example"))

      perform_enqueued_jobs { transfer(to: boreal) }

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ "rh@padaria.example" ])
      expect(mail.body.encoded).to include("boreal.painel.catalysthr.com.br")
      expect(mail[:from].display_names).to eq([ "Boreal RH" ])
    end
  end

  describe "from a partner to the direct modality (D-599)" do
    it "makes the company direct with its own brand at the given slug" do
      result = transfer(to: nil, slug: "padaria")

      expect(result).to be_success
      expect(company.reload).to be_direct
      expect(company.brand_display_mode).to be_nil
      expect(company.brand).to have_attributes(commercial_name: "Padaria Pão Quente", primary_color: nil)
      expect(company.brand.active_subdomain.slug).to eq("padaria")
      expect(Brands::HostLookup.call("padaria").brand_id).to eq(company.brand.id)
    end

    it "turns the company's own brand into the direct company's" do
      own = create(:brand, owner: company, commercial_name: "Padaria RH", primary_color: "#9E3422")

      transfer(to: nil, slug: "padaria")

      expect(company.reload.brand).to eq(own)
      expect(own.active_subdomain.slug).to eq("padaria")
    end

    it "asks for the slug and refuses one in use, changing nothing" do
      expect(transfer(to: nil).errors).to eq([ "Informe o endereço da empresa direta." ])

      result = transfer(to: nil, slug: "boreal")

      expect(result).not_to be_success
      expect(company.reload.partner).to eq(aurora)
      expect(CompanyTransfer.count).to eq(0)
    end
  end

  describe "from the direct modality to a partner (D-599)" do
    let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
    let!(:brand) do
      create(:brand, owner: company, commercial_name: "Serra Azul RH", email_domain: "serraazul.com.br",
        email_domain_status: "verified").tap { |brand| brand.subdomains.create!(slug: "serraazul") }
    end

    it "answers 404 at the old address, keeps the slug reserved for 90 days and removes the e-mail domain" do
      ses = stub_ses

      result = transfer(to: boreal)

      expect(result).to be_success
      expect(company.reload).to have_attributes(partner: boreal, brand_display_mode: "alongside")
      expect(Brands::HostLookup.call("serraazul")).to be_nil
      subdomain = brand.subdomains.find_by(slug: "serraazul")
      expect(subdomain).to be_redirecting
      expect(subdomain.redirect_until).to be_within(1.minute).of(90.days.from_now)
      expect(BrandSubdomain.new(brand: create(:brand), slug: "serraazul")).not_to be_valid
      expect(brand.reload).to have_attributes(email_domain: nil, commercial_name: "Serra Azul RH")
      expect(ses.api_requests.map { |request| request[:operation_name] }).to include(:delete_email_identity)
    end

    it "changes nothing when SES does not answer" do
      stub_ses(delete_email_identity: "ServiceUnavailable")

      result = transfer(to: boreal)

      expect(result.errors).to eq([ "Não foi possível remover o domínio de e-mail da marca agora. Tente de novo em alguns minutos." ])
      expect(company.reload).to be_direct
      expect(brand.reload.active_subdomain.slug).to eq("serraazul")
    end

    it "gets the old slug back when the company becomes direct again" do
      stub_ses
      transfer(to: boreal)

      described_class.call(company: company.reload, to_partner: nil, performed_by: superadmin,
        authorized_by_text: "Pedido da empresa", slug: "serraazul")

      expect(brand.reload.active_subdomain.slug).to eq("serraazul")
      expect(brand.subdomains.count).to eq(1)
    end
  end

  describe "the authorization (RN-01-050)" do
    it "is required" do
      expect(transfer(to: boreal, text: " ").errors).to eq([ "Registre a autorização da empresa." ])
    end

    it "keeps the document under the company's prefix (RN-01-014)" do
      document = fixture_file_upload("logo.png", "image/png")

      result = transfer(to: boreal, document: document)

      expect(result.transfer.authorization_document.blob.key).to start_with("companies/#{company.id}/transfers/")
    end

    it "refuses a document that is not a PDF or an image" do
      # A text file with an image's name
      document = fixture_file_upload("fake.png", "image/png")

      expect(transfer(to: boreal, document: document).errors).to include("O documento precisa ser um PDF ou uma imagem PNG, JPEG ou WebP.")
    end
  end

  it "refuses the same owner and a partner without an address" do
    expect(transfer(to: aurora).errors).to eq([ "A empresa já pertence a esse dono." ])
    expect(transfer(to: create(:partner)).errors).to eq([ "O parceiro escolhido ainda não tem marca com endereço." ])
  end
end
