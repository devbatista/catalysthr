require "rails_helper"

# Spec 19, RN-19-102 (D-632, D-633): what goes on every NFS-e, kept in a single row.
RSpec.describe FiscalSetting do
  let(:user) { create(:user, platform_role: "finance") }

  def setting(**attributes)
    described_class.current.tap { |record| record.assign_attributes({ service_code: "010501", updated_by: user }.merge(attributes)) }
  end

  it "starts from the accountant's values of D-632, without a service code" do
    expect(described_class.current).to have_attributes(new_record?: true, service_code: nil, nbs_code: "1.1506.21.00",
      operation_indicator_code: "100501", description: "Licenciamento de software CatalystHR por assinatura")
  end

  it "keeps a single row" do
    setting.save!

    expect(described_class.current).to be_persisted
    expect { described_class.create!(setting.attributes.except("id", "created_at", "updated_at")) }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "takes the NBS only with its dots, as Asaas does" do
    expect(setting(nbs_code: "1.1506.21.00")).to be_valid
    expect(setting(nbs_code: "115062100")).not_to be_valid
  end

  it "takes six digits as the operation indicator and rates between 0 and 100" do
    expect(setting(operation_indicator_code: "10050")).not_to be_valid
    expect(setting(ir_rate: 101)).not_to be_valid
    expect(setting(pis_rate: 0.65)).to be_valid
  end

  it "asks for the service code, the description and the observations" do
    record = setting(service_code: " ", description: "", observations: "")

    expect(record).not_to be_valid
    expect(record.errors.attribute_names).to include(:service_code, :description, :observations)
  end
end
