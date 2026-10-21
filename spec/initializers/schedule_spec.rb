require "rails_helper"

# Without a time zone, sidekiq-cron reads a cron in the Rails time zone (et-orbi), so a
# time written in UTC ran 3 hours late (D-108).
RSpec.describe "Scheduled jobs" do
  schedule = YAML.load_file(Rails.root.join("config/schedule.yml"))

  schedule.each do |name, job|
    it "#{name} names its time zone and a job that exists" do
      cron = Fugit::Cron.parse(job.fetch("cron"))

      expect(cron&.zone).to eq("America/Sao_Paulo")
      expect(job.fetch("class").safe_constantize).to be_present
      expect(Sidekiq::Cron::Job.new(job.merge("name" => name))).to be_valid
    end
  end

  it "runs the invoices at 02:00 in Brasília, 05:00 UTC" do
    cron = Fugit::Cron.parse(schedule.dig("billing_generate_invoices", "cron"))

    expect(cron.next_time(Time.utc(2026, 10, 21, 12)).utc).to eq(Time.utc(2026, 10, 22, 5))
  end
end
