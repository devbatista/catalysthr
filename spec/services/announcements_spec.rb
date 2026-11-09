require "rails_helper"

# Spec 15, block 15e (RN-15-070 to RN-15-074, RN-15-091, CA-15-011, D-656): the board of notices,
# its audience read when someone opens the board, the publication that waits for the
# attachment's scan, the notice to the audience, the end of the validity and the history's
# two years.
RSpec.describe "Board of notices" do
  include ActiveJob::TestHelper

  let(:company) { create(:company) }
  let!(:hr_user) { create(:user, name: "Juliana Ribeiro") }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let(:position) { create_position(company) }
  let(:centro) { in_company { Unit.create!(name: "Centro") } }
  let(:filial) { in_company { Unit.create!(name: "Filial") } }
  let!(:ana) { employee("Ana Lima", centro) }
  let!(:bruno) { employee("Bruno Reis", filial) }

  before do
    travel_to Time.zone.local(2026, 11, 9, 10)
    Flipper.enable(FeatureFlags::ANNOUNCEMENTS)
  end

  after { travel_back }

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  def employee(name, unit, **attributes)
    profile = register_employee(company, by: hr_user, position: position, name: name, unit: unit, **attributes)
    in_company { profile.membership.update!(status: "active") }
    profile
  end

  def form(announcement = in_company { Announcement.new }, by: hr_user, unit_ids: :all, **attributes)
    in_company do
      Announcements::Form.new(announcement, by: by, unit_ids: unit_ids,
        **{ title: "Recesso de fim de ano", body: "O escritório fecha de 24/12 a 01/01.\nBoas festas!", mode: "now",
            expires_on: "2026-12-31", audience: {} }.merge(attributes))
    end
  end

  def publish(**attributes)
    built = form(**attributes)
    raise built.errors.full_messages.to_sentence unless in_company { built.save }

    built.announcement
  end

  def image_upload
    Rack::Test::UploadedFile.new(StringIO.new("\x89PNG\r\n\x1A\n#{"x" * 32}".b), "image/png", original_filename: "aviso.png")
  end

  def notices_for(profile)
    Notification.where(recipient_user: profile.user, notification_type: "announcements.published")
  end

  def reaching(profile) = in_company { Announcement.reaching(profile).to_a }

  describe "the audience (RN-15-071, CA-15-011)" do
    it "puts a notice for the Centro unit only on its people's board, and tells only them" do
      announcement = perform_enqueued_jobs(only: Announcements::NotifyJob) { publish(audience: { "unit_ids" => [ centro.id ] }) }

      expect(announcement.reload).to be_published
      expect(reaching(ana)).to eq([ announcement ])
      expect(reaching(bruno)).to be_empty
      expect(notices_for(ana).sole.title).to eq("Comunicado: Recesso de fim de ano")
      expect(notices_for(ana).sole.body).to eq("O escritório fecha de 24/12 a 01/01.\nBoas festas!")
      expect(notices_for(bruno)).to be_empty
    end

    it "reaches everyone without a filter, and between lists asks for all of them" do
      everyone = publish
      interns = publish(title: "Estágio", audience: { "unit_ids" => [ centro.id ], "employment_kinds" => %w[intern] })

      expect(reaching(ana)).to eq([ everyone ])
      expect(reaching(bruno)).to eq([ everyone ])
      expect(in_company { interns.audience_filter.profiles.to_a }).to be_empty
      expect(in_company { everyone.audience_filter.members.count }).to eq(2)
    end

    it "shows the notice to who joins later, without a notice for them (D-656)" do
      announcement = perform_enqueued_jobs(only: Announcements::NotifyJob) { publish(audience: { "unit_ids" => [ centro.id ] }) }
      carla = employee("Carla Dias", centro)

      expect(reaching(carla)).to eq([ announcement ])
      expect(notices_for(carla)).to be_empty
    end

    it "makes no second notice when the job runs again (RN-15-085)" do
      announcement = publish
      2.times { perform_enqueued_jobs { in_company { Announcements::NotifyJob.perform_later(announcement) } } }

      expect(notices_for(ana).count).to eq(1)
    end

    it "keeps the HR analyst to their units (P-15-22)" do
      outside = form(unit_ids: [ centro.id ], audience: { "unit_ids" => [ filial.id ] })
      none = form(unit_ids: [ centro.id ], audience: {})
      own = form(unit_ids: [ centro.id ], audience: { "unit_ids" => [ centro.id ] })

      expect(in_company { outside.valid? }).to be(false)
      expect(outside.errors.full_messages).to include("Público precisa ter ao menos uma das suas unidades, e só as suas")
      expect(in_company { none.valid? }).to be(false)
      expect(in_company { own.valid? }).to be(true)
    end
  end

  describe "the publication (RN-15-071, D-656)" do
    it "waits for the attachment's scan, and goes up when it is clean" do
      announcement = publish(file: image_upload)

      expect(announcement.reload).to be_scheduled
      expect(announcement.scan_status).to eq("scanning")
      perform_enqueued_jobs(only: Announcements::NotifyJob) do
        announcement.attachment.blob.file_scan.record!(Antivirus::Clamd::Result.new(signature: nil))
      end

      expect(announcement.reload).to be_published
      expect(announcement.attachment_clean?).to be(true)
      expect(notices_for(ana).count).to eq(1)
    end

    it "sends the notice back to the drafts when the attachment has a virus" do
      announcement = publish(file: image_upload)
      announcement.attachment.blob.file_scan.record!(Antivirus::Clamd::Result.new(signature: "Eicar-Test-Signature"))

      expect(announcement.reload).to be_draft
      expect(announcement.scan_status).to eq("infected")
      retry_form = form(announcement, mode: "now")
      expect(in_company { retry_form.valid? }).to be(false)
      expect(retry_form.errors.full_messages.join).to include("tinha vírus")
    end

    it "schedules for later, in the headquarters' time zone, and the job puts it up" do
      announcement = publish(mode: "schedule", publish_at: "2026-11-10T08:00")

      expect(announcement.reload).to be_scheduled
      expect(announcement.publish_at).to eq(Time.find_zone("America/Sao_Paulo").local(2026, 11, 10, 8))
      travel_to Time.zone.local(2026, 11, 10, 8, 5) do
        Announcements::PublishScheduledJob.perform_now
      end
      expect(announcement.reload).to be_published
    end

    it "refuses a schedule in the past and a validity before the publication" do
      past = form(mode: "schedule", publish_at: "2026-11-08T08:00")
      before = form(mode: "schedule", publish_at: "2026-12-10T08:00", expires_on: "2026-12-01")

      expect(in_company { past.valid? }).to be(false)
      expect(in_company { before.valid? }).to be(false)
      expect(before.errors.full_messages).to include("Validade precisa ser depois da publicação")
    end

    it "keeps a draft off the board" do
      draft = publish(mode: "draft")

      expect(draft.reload).to be_draft
      expect(in_company { Announcement.reaching(ana).live.to_a }).to be_empty
    end

    it "waits with the board's flag off" do
      Flipper.disable(FeatureFlags::ANNOUNCEMENTS)
      announcement = publish

      expect(announcement.reload).to be_scheduled
      Flipper.enable(FeatureFlags::ANNOUNCEMENTS)
      Announcements::PublishScheduledJob.perform_now
      expect(announcement.reload).to be_published
    end

    it "changes only the validity and the pin of a published notice (D-656)" do
      announcement = publish
      edit = form(announcement, title: "Outro título", body: "Outro texto", pinned: "1", expires_on: "2026-12-15")

      expect(in_company { edit.save }).to be(true)
      expect(announcement.reload).to have_attributes(title: "Recesso de fim de ano", pinned: true, status: "published")
      expect(announcement.expires_at.to_date).to eq(Date.new(2026, 12, 15))
    end
  end

  describe "the validity and the history (RN-15-071, RN-15-091)" do
    it "ends the notice after its validity's day, and keeps it in the history" do
      announcement = publish(expires_on: "2026-11-10")

      travel_to Time.zone.local(2026, 11, 11, 0, 5) do
        Announcements::PublishScheduledJob.perform_now
        expect(announcement.reload).to be_expired
        expect(in_company { Announcement.reaching(ana).live.to_a }).to be_empty
        expect(in_company { Announcement.reaching(ana).past.to_a }).to eq([ announcement ])
      end
    end

    it "deletes the notice, its reads and its file 2 years after the validity" do
      announcement = publish(expires_on: "2026-11-10", file: image_upload)
      in_company { AnnouncementRead.record!(announcement, ana.membership) }
      kept = publish(expires_on: "2026-12-31")

      travel_to Time.zone.local(2028, 11, 12, 3) do
        perform_enqueued_jobs { Notifications::PurgeJob.perform_now }
      end
      expect(in_company { Announcement.where(id: announcement.id) }).to be_empty
      expect(in_company { AnnouncementRead.count }).to eq(0)
      expect(ActiveStorage::Blob.where(id: announcement.attachment.blob.id)).to be_empty
      expect(in_company { Announcement.where(id: kept.id) }).to exist
    end
  end

  describe "who does what (RN-15-070, spec 15 section 6, D-656)" do
    def ability(user) = Ability.new(user, area: :panel, company: company)

    let(:analyst_user) { create(:user) }
    let!(:analyst) { create(:membership, user: analyst_user, organization: company, roles: %w[hr_analyst]) }

    it "lets the HR administrator publish, edit, withdraw and see the reads of any notice" do
      announcement = publish(by: analyst_user, unit_ids: [ centro.id ], audience: { "unit_ids" => [ centro.id ] })

      expect(ability(hr_user)).to be_able_to(:create, Announcement)
      %i[update withdraw read_reads].each { |action| expect(ability(hr_user)).to be_able_to(action, announcement) }
      expect(ability(hr_user).announcement_unit_ids).to eq(:all)
    end

    it "lets the HR analyst publish to their units and manage only their own" do
      in_company { MembershipUnit.create!(membership: analyst, unit: centro) }
      own = publish(by: analyst_user, unit_ids: [ centro.id ], audience: { "unit_ids" => [ centro.id ] })
      admins = publish

      expect(ability(analyst_user)).to be_able_to(:create, Announcement)
      expect(ability(analyst_user)).to be_able_to(:read_reads, own)
      expect(ability(analyst_user)).not_to be_able_to(:update, admins)
      expect(ability(analyst_user)).not_to be_able_to(:read_reads, admins)
      expect(ability(analyst_user).announcement_unit_ids).to eq([ centro.id ])
    end

    it "shows the HR analyst in the panel those for everyone and those of their units" do
      in_company { MembershipUnit.create!(membership: analyst, unit: centro) }
      everyone = publish
      at_centro = publish(audience: { "unit_ids" => [ centro.id ] })
      publish(audience: { "unit_ids" => [ filial.id ] })

      expect(in_company { Announcement.in_panel([ centro.id ]).to_a }).to contain_exactly(everyone, at_centro)
    end

    it "does not let an HR analyst without units publish" do
      expect(ability(analyst_user)).not_to be_able_to(:create, Announcement)
      expect(ability(analyst_user)).to be_able_to(:read, Announcement)
    end

    it "lets the partner's consultant only read the board (D-656)" do
      partner = create(:partner)
      company.update!(partner: partner)
      consultant = create(:membership, organization: partner, roles: %w[consultant], status: "active")
      consultant.partner_membership_companies.create!(company: company)

      expect(ability(consultant.user)).to be_able_to(:read, Announcement)
      expect(ability(consultant.user)).not_to be_able_to(:create, Announcement)
      expect(ability(consultant.user)).not_to be_able_to(:withdraw, publish)
    end

    it "gives the board to the employee, and not to who is in a read-only period (RN-16-051)" do
      expect(ability(ana.user)).to be_able_to(:read_board, Announcement)
      in_company { ana.membership.update!(status: "read_only") }
      expect(ability(ana.user)).not_to be_able_to(:read_board, Announcement)
    end
  end
end
