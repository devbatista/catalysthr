require "rails_helper"

# Spec 06, block 06b-1 (RN-06-001 to RN-06-042, D-639): the models of process and their
# items, at the three levels, without one company reaching another's.
RSpec.describe "Models of process" do
  let(:partner) { create(:partner) }
  let(:company) { create(:company, partner: partner) }
  let(:other_company) { create(:company) }

  def in_company(target = company, &)
    ActsAsTenant.with_tenant(target, &)
  end

  def task(template, title, **attributes)
    template.items.create!(position: template.items.count + 1, kind: "task", title: title, responsible_role: "hr", **attributes)
  end

  describe "isolation (D-639, P-06-19)" do
    it "never lets a company reach another's models, nor the shared ones reach a company's" do
      library = SharedProcessTemplate.create!(kind: "admission", name: "Admissão CLT padrão")
      own = in_company { ProcessTemplate.create!(kind: "admission", name: "Admissão da Padaria") }
      in_company(other_company) { ProcessTemplate.create!(kind: "admission", name: "Admissão de outra") }

      expect(in_company { ProcessTemplate.pluck(:id) }).to eq([ own.id ])
      expect(SharedProcessTemplate.pluck(:id)).to eq([ library.id ])
      expect { ProcessTemplate.count }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
      expect(in_company { ProcessTemplateItem.where(process_template_id: library.id) }).to be_empty
    end
  end

  describe "items" do
    let(:template) { in_company { ProcessTemplate.create!(kind: "admission", name: "Admissão") } }

    it "refuses dependencies in a cycle (RN-06-041, CA-06-008)" do
      in_company do
        a = task(template, "A")
        b = task(template, "B", depends_on_item_ids: [ a.id ])

        a.depends_on_item_ids = [ b.id ]
        expect(a).not_to be_valid
        expect(a.errors[:depends_on_item_ids]).to include(match(/ciclo/))
        expect(b.reload.depends_on_item_ids).to eq([ a.id ])
      end
    end

    it "refuses a dependency on another model's item" do
      in_company do
        other = ProcessTemplate.create!(kind: "admission", name: "Outro")
        foreign = task(other, "De outro modelo")

        expect(template.items.build(position: 1, kind: "task", title: "A", responsible_role: "hr",
          depends_on_item_ids: [ foreign.id ])).not_to be_valid
      end
    end

    it "takes the deadline from the model kind's dates (RN-06-025)" do
      in_company do
        item = template.items.build(position: 1, kind: "task", title: "A", responsible_role: "hr", due_anchor: "termination",
          due_offset_days: 3)
        expect(item).not_to be_valid

        item.due_anchor = "work_start"
        item.due_offset_days = -3
        expect(item).to be_valid
        item.due_anchor = nil
        expect(item.tap(&:validate).due_offset_days).to be_nil
      end
    end

    it "takes conditions by position and unit only from the company (RN-06-035, CA-06-002)" do
      foreign_unit = in_company(other_company) { Unit.create!(name: "Unidade de outra") }
      in_company do
        unit = Unit.create!(name: "Caxias")
        item = template.items.build(position: 1, kind: "task", title: "Integração de segurança", responsible_role: "hr",
          conditions: { "unit_ids" => [ unit.id ], "employment_kinds" => [ "clt", "" ] })
        expect(item).to be_valid
        expect(item.conditions).to eq("employment_kinds" => [ "clt" ], "unit_ids" => [ unit.id ])

        item.conditions = { "unit_ids" => [ foreign_unit.id ] }
        expect(item).not_to be_valid
      end

      library = SharedProcessTemplate.create!(kind: "admission", name: "Biblioteca")
      shared = library.items.build(position: 1, kind: "task", title: "A", responsible_role: "hr",
        conditions: { "unit_ids" => [ foreign_unit.id ] })
      expect(shared).not_to be_valid
      expect(shared.errors[:conditions]).to include(match(/só valem no modelo da empresa/))
      shared.conditions = { "employment_kinds" => %w[intern] }
      expect(shared).to be_valid
    end

    it "asks a form for something to fill and a forward for something to send (RN-06-030, RN-06-065)" do
      in_company do
        form = template.items.build(position: 1, kind: "form", title: "Dados bancários", responsible_role: "employee")
        expect(form).not_to be_valid
        form.config = { "groups" => %w[bank_account nonsense], "free_fields" => [ "Tamanho do uniforme", " " ] }
        expect(form).to be_valid
        expect(form.config).to eq("groups" => %w[bank_account], "custom_field_keys" => [], "free_fields" => [ "Tamanho do uniforme" ])

        forward = template.items.build(position: 2, kind: "forward", title: "Encaminhar à contabilidade", responsible_role: "hr",
          config: { "record" => "0", "validated_documents" => "0" })
        expect(forward).not_to be_valid
        forward.config = { "validated_documents" => "1" }
        expect(forward).to be_valid
      end
    end
  end

  describe "the company's default and the onboarding (RN-06-003, RN-06-004)" do
    it "keeps one active default per kind, and archiving drops it" do
      in_company do
        first = ProcessTemplate.create!(kind: "admission", name: "Admissão CLT", status: "active")
        second = ProcessTemplate.create!(kind: "admission", name: "Admissão estágio", status: "active")
        draft = ProcessTemplate.create!(kind: "admission", name: "Rascunho")

        first.make_default!
        second.make_default!
        expect(first.reload.is_default).to be(false)
        expect(second.reload.is_default).to be(true)
        expect { draft.make_default! }.to raise_error(ActiveRecord::RecordInvalid)

        second.archive!
        expect(second.reload).to have_attributes(status: "archived", is_default: false)
      end
    end

    it "links an admission only to an onboarding of the company" do
      in_company do
        admission = ProcessTemplate.create!(kind: "admission", name: "Admissão", status: "active")
        onboarding = ProcessTemplate.create!(kind: "onboarding", name: "Integração", status: "active")
        offboarding = ProcessTemplate.create!(kind: "offboarding", name: "Desligamento", status: "active")

        expect(admission.update(onboarding_template: offboarding)).to be(false)
        expect(admission.update(onboarding_template: onboarding)).to be(true)
        expect(onboarding.update(onboarding_template: onboarding)).to be(false)
      end
    end

    it "lets a position point only to an active admission model (D-204)" do
      CboOccupation.create!(code: "784205", title: "Alimentador de linha de produção")
      in_company do
        position = Position.create!(name: "Auxiliar", cbo_code: "784205")
        draft = ProcessTemplate.create!(kind: "admission", name: "Rascunho")
        active = ProcessTemplate.create!(kind: "admission", name: "Admissão", status: "active")

        expect(position.update(admission_template: draft)).to be(false)
        expect(position.update(admission_template: active)).to be(true)
      end
    end
  end
end
