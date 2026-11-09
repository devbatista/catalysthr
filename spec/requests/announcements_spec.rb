require "rails_helper"

# Spec 15, block 15e (RN-15-070 to RN-15-074, CA-15-011, D-656): the HR's board in the panel and
# the board in the portal, with the reads, the HR analyst's units and the flag.
RSpec.describe "Announcements", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_user) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let(:position) { create_position(company) }
  let(:centro) { in_company { Unit.create!(name: "Centro") } }
  let(:filial) { in_company { Unit.create!(name: "Filial") } }
  let!(:ana) { employee("Ana Lima", centro, "52998224725") }
  let!(:bruno) { employee("Bruno Reis", filial, "39053344705") }

  before do
    travel_to Time.zone.local(2026, 11, 9, 10)
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::ANNOUNCEMENTS)
    publish_platform_legal_documents
    host! "serraazul.painel.catalysthr.com.br"
  end

  after { travel_back }

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  def employee(name, unit, cpf)
    profile = register_employee(company, by: hr_user, position: position, name: name, unit: unit, cpf: cpf)
    profile.user.update!(password: "Catalyst#2026", password_confirmation: "Catalyst#2026")
    in_company { profile.membership.update!(status: "active") }
    profile
  end

  def sign_in_hr(user = hr_user)
    accept_legal_documents(user, brand)
    sign_in_with_mfa(user.cpf, user)
  end

  def sign_in_employee(profile)
    accept_legal_documents(profile.user, brand)
    post "/sign-in", params: { user: { login: profile.user.cpf, password: "Catalyst#2026" } }
  end

  def params_for(audience: {}, **announcement)
    { announcement: { title: "Recesso de fim de ano", body: "O escritório fecha de 24/12 a 01/01.", mode: "now",
      expires_on: "2026-12-31", pinned: "0" }.merge(announcement), audience: audience }
  end

  def announcement_for(audience = {}, by: hr_user, **attributes)
    in_company do
      form = Announcements::Form.new(Announcement.new, by: by, unit_ids: :all, title: "Recesso", body: "Texto do recesso.", mode: "now",
        expires_on: "2026-12-31", audience: audience, **attributes)
      form.save or raise form.errors.full_messages.to_sentence
      form.announcement
    end
  end

  describe "the HR's board" do
    it "publishes a notice for a unit, which reaches only its people (CA-15-011)" do
      sign_in_hr
      get "/"
      expect(response.body).to include("Comunicados")

      get "/announcements/new"
      expect(response.body).to include("não tem valor de ciência", "Centro", "Filial", "Agendar")

      perform_enqueued_jobs(only: Announcements::NotifyJob) do
        post "/announcements", params: params_for(audience: { unit_ids: [ centro.id ] })
      end
      announcement = in_company { Announcement.sole }
      expect(response).to redirect_to("/announcements/#{announcement.id}")
      expect(announcement).to be_published
      expect(Notification.where(notification_type: "announcements.published").pluck(:recipient_user_id)).to eq([ ana.user.id ])

      follow_redirect!
      expect(response.body).to include("Comunicado publicado", "Unidades: Centro", "0 de 1")
    end

    it "shows the errors of the form" do
      sign_in_hr
      post "/announcements", params: params_for(title: "", mode: "schedule", publish_at: "")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Título não pode ficar em branco", "Data e hora da publicação precisa ser informada para agendar")
    end

    it "withdraws a notice, which leaves the portal's board" do
      announcement = announcement_for
      sign_in_hr
      patch "/announcements/#{announcement.id}/withdraw"

      expect(announcement.reload).to be_withdrawn
      expect(announcement.withdrawn_by).to eq(hr_user)
      expect(in_company { Announcement.reaching(ana).live }).to be_empty
    end

    it "keeps the HR analyst to their units and their own notices (P-15-22, D-656)" do
      analyst_user = enable_mfa(create(:user, name: "Paula Souza", cpf: "86288366757"))
      analyst = create(:membership, user: analyst_user, organization: company, roles: %w[hr_analyst])
      in_company { MembershipUnit.create!(membership: analyst, unit: centro) }
      at_filial = announcement_for({ "unit_ids" => [ filial.id ] })
      everyone = announcement_for
      sign_in_hr(analyst_user)

      get "/announcements"
      expect(response.body).to include("/announcements/#{everyone.id}")
      expect(response.body).not_to include("/announcements/#{at_filial.id}")
      get "/announcements/#{at_filial.id}"
      expect(response).to have_http_status(:not_found)

      get "/announcements/#{everyone.id}"
      expect(response.body).not_to include("Abriram", "Retirar do mural", "Editar")

      get "/announcements/new"
      expect(response.body).to include("Centro")
      expect(response.body).not_to include("Filial")
      post "/announcements", params: params_for(audience: { unit_ids: [ filial.id ] })
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "is not there with the flag off" do
      Flipper.disable(FeatureFlags::ANNOUNCEMENTS)
      sign_in_hr
      get "/"
      expect(response.body).not_to include("/announcements")
      get "/announcements"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "the portal's board (RN-15-072, RN-16-011, RN-16-020)" do
    it "lists the person's notices, highlights them on the start and counts the reading" do
      announcement = announcement_for({ "unit_ids" => [ centro.id ] }, pinned: "1")
      sign_in_employee(ana)

      get "/portal"
      expect(response.body).to include("Comunicados", "Recesso", "Fixado", "Novo")
      get "/portal/more"
      expect(response.body).to include("Mural de comunicados")

      get "/portal/announcements/#{announcement.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Texto do recesso.")
      expect(in_company { AnnouncementRead.where(announcement: announcement, membership: ana.membership).count }).to eq(1)

      get "/portal/announcements"
      expect(response.body).to include("Recesso", "Fixado")
      expect(response.body).not_to include(">Novo<")
    end

    it "answers 404 to a notice outside the person's audience (CA-15-011)" do
      announcement = announcement_for({ "unit_ids" => [ centro.id ] })
      sign_in_employee(bruno)

      get "/portal/announcements/#{announcement.id}"
      expect(response).to have_http_status(:not_found)
      get "/portal/announcements"
      expect(response.body).to include("Nenhum comunicado no momento.")
    end

    it "shows the reads to the HR against the audience (RN-15-072)" do
      announcement = announcement_for
      in_company { AnnouncementRead.record!(announcement, ana.membership) }
      sign_in_hr

      get "/announcements/#{announcement.id}"
      expect(response.body).to include("1 de 2")
    end
  end
end
