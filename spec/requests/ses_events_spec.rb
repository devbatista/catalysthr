require "rails_helper"

# Spec 15, RN-15-080 and RN-15-083 (P-15-24, P-15-26, CA-15-009, D-609): the SES events
# that SNS posts, signed and from the app's topic.
RSpec.describe "SES events", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company) }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let(:hr_admin) { create(:user, name: "Juliana Ribeiro", email: "juliana@serraazul.example") }
  let(:person) { create(:user, name: "Ana Lima", email: "ana@example.com") }
  let!(:person_membership) { create(:membership, user: person, organization: company, roles: %w[manager]) }

  before do
    create(:membership, user: hr_admin, organization: company, roles: %w[hr_admin])
    brand.subdomains.create!(slug: "serraazul")
    stub_sns_certificate
    host! "admin.catalysthr.com.br"
  end

  def bounce(type = "Permanent", address: "ana@example.com", message_id: "ses-1")
    ses_event("Bounce", message_id: message_id, bounce: { bounceType: type, bouncedRecipients: [ { emailAddress: address } ] })
  end

  it "refuses a message that SNS did not sign, or from another topic" do
    post_sns(sns_message(message: bounce, key: OpenSSL::PKey::RSA.new(2048)))
    expect(response).to have_http_status(:forbidden)

    post_sns(sns_message(message: bounce, topic: "arn:aws:sns:sa-east-1:111111111111:other"))
    expect(response).to have_http_status(:forbidden)

    post_sns("not json")
    expect(response).to have_http_status(:bad_request)
    expect(person.reload).to be_email_valid
  end

  it "confirms the topic's subscription only at AWS's address" do
    confirm = stub_request(:get, "https://sns.sa-east-1.amazonaws.com/?Action=ConfirmSubscription&Token=token").to_return(status: 200)

    post_sns(sns_message(type: "SubscriptionConfirmation", subscribe_url: "https://evil.example/confirm"))
    expect(response).to have_http_status(:forbidden)

    post_sns(sns_message(type: "SubscriptionConfirmation",
      subscribe_url: "https://sns.sa-east-1.amazonaws.com/?Action=ConfirmSubscription&Token=token"))
    expect(response).to have_http_status(:ok)
    expect(confirm).to have_been_requested.once
  end

  it "marks a delivery delivered" do
    notification = perform_enqueued_jobs do
      Notifications.notify!("security.mfa_reset", user: person, membership: person_membership, path: "/security", brand_name: "X")
    end
    delivery = notification.deliveries.sole
    delivery.update!(provider_message_id: "ses-9")

    post_sns(sns_message(message: ses_event("Delivery", message_id: "ses-9")))

    expect(delivery.reload).to have_attributes(status: "delivered", delivered_at: be_present)
  end

  it "marks a permanent bounce invalid, tells the HR once and stops every e-mail (CA-15-009, D-609)" do
    2.times { post_sns(sns_message(message: bounce)) }

    expect(response).to have_http_status(:ok)
    expect(person.reload).to have_attributes(email_status: "bounced", email_status_at: be_present)
    notice = Notification.find_by!(notification_type: "contacts.email_invalid")
    expect(notice).to have_attributes(recipient_user: hr_admin, title: "O e-mail de Ana Lima voltou", path: "/users/#{person_membership.id}")
    expect(Notification.where(notification_type: "contacts.email_invalid").count).to eq(1)
    expect(notice.body).not_to include("ana@example.com")

    expect { Invitations.issue(person_membership.tap { |m| m.update!(status: "invited") }, channels: %w[email], invited_by: hr_admin) }
      .to raise_error(ActiveRecord::RecordInvalid, /voltou e está marcado como inválido/)
    expect(Notifications.notify!("security.contact_changed", user: person, path: "/security", brand_name: "X")).to be_nil
    # The last guard: nothing goes to the bounced address, whatever the mailer.
    AccountMailer.contact_changed(person, "ana@example.com").deliver_now
    CompanyMailer.transferred(person_membership).deliver_now
    AccountMailer.contact_changed(hr_admin, "juliana.antiga@example.com").deliver_now
    expect(ActionMailer::Base.deliveries.map(&:to)).to eq([ [ "juliana.antiga@example.com" ] ])
  end

  it "ignores a temporary bounce" do
    post_sns(sns_message(message: bounce("Transient")))

    expect(person.reload).to be_email_valid
  end

  it "stops the optional notices to an address that complained of spam, keeping the mandatory ones" do
    post_sns(sns_message(message: ses_event("Complaint", complaint: { complainedRecipients: [ { emailAddress: "Ana@Example.com" } ] })))

    expect(person.reload).to be_email_complained
    expect(person.email_deliverable?(mandatory: false)).to be(false)
    expect(person.email_deliverable?(mandatory: true)).to be(true)
  end

  it "makes a new e-mail valid again" do
    person.update!(email_status: "bounced", email_status_at: Time.current)

    person.update!(email: "ana.nova@example.com")

    expect(person.reload).to be_email_valid
  end
end
