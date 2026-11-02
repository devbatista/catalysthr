require "rails_helper"

# Spec 06, block 06c (RN-06-020 to RN-06-053, D-641): starting a process from the
# company's model, its items' people, dates and blocks, the actions on them and what
# follows the employment.
RSpec.describe "Processes" do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Padaria Pão Quente") }
  let(:hr_user) { create(:user, name: "Juliana Ribeiro") }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let(:position) { create_position(company) }
  let(:caxias) { company.headquarters }
  let(:bento) { ActsAsTenant.with_tenant(company) { Unit.create!(name: "Bento") } }
  let(:profile) { register_employee(company, by: hr_user, position: position, unit: caxias) }
  let(:employment) { profile.employments.sole }
  let(:template) { in_company { ProcessTemplate.create!(kind: "admission", name: "Admissão CLT") } }

  # Every example runs inside the company, as the specs that start processes will.
  around { |example| ActsAsTenant.with_tenant(company) { example.run } }

  def in_company
    yield
  end

  def item(title, **attributes)
    in_company do
      template.items.create!({ position: template.items.count + 1, kind: "task", title: title, responsible_role: "hr" }.merge(attributes))
    end
  end

  def start(anchors: { "work_start" => Date.new(2026, 11, 20) }, mode: "confirm")
    template.update!(status: "active") unless template.active?
    in_company do
      Processes::Start.call(template: template.reload, employment: employment, started_by: hr_user, starter: hr, anchors: anchors,
        completion_mode: mode)
    end
  end

  def items_of(instance)
    in_company { instance.items.reload.index_by(&:title) }
  end

  it "keeps only the items whose conditions hold (RN-06-035, CA-06-002)" do
    item("Integração de segurança", conditions: { "unit_ids" => [ bento.id ] })
    item("Boas-vindas", conditions: { "employment_kinds" => [ employment.kind ], "unit_ids" => [ caxias.id, bento.id ] })

    instance = start

    expect(items_of(instance).keys).to eq([ "Boas-vindas" ])
    expect(instance).to have_attributes(status: "open", unit_id: caxias.id, completion_mode: "confirm",
      subject_snapshot: include("unit_id" => caxias.id, "position_id" => position.id))
    expect(in_company { instance.events.map(&:action) }).to eq(%w[started])
  end

  it "counts business days around the holidays of the unit (RN-06-026, CA-06-003)" do
    Holiday.create!(level: "national", date: Date.new(2026, 11, 20), name: "Consciência Negra", status: "published")
    item("Exame admissional", due_anchor: "work_start", due_offset_days: -3, due_business_days: true)
    item("Crachá", due_anchor: "work_start", due_offset_days: 2, due_business_days: false)

    items = items_of(start(anchors: { "work_start" => Date.new(2026, 11, 23) }))

    # Monday 23/11 minus 3 business days, skipping Friday 20/11 and the weekend.
    expect(items["Exame admissional"].due_on).to eq(Date.new(2026, 11, 17))
    expect(items["Crachá"].due_on).to eq(Date.new(2026, 11, 25))
  end

  it "sends a role with nobody to the HR, with the alert (RN-06-022, CA-06-006)" do
    item("Apresentar a equipe", responsible_role: "manager")

    instance = start
    manager_item = items_of(instance)["Apresentar a equipe"]

    expect(manager_item).to have_attributes(responsible_membership_ids: [ hr.id ], responsible_fallback: true)
    expect(in_company { instance.reload.responsible_alert? }).to be(true)
  end

  it "gives the item to every manager of the client, and follows a change of client (CA-06-009, CA-06-010)" do
    company.update!(uses_allocation_clients: true)
    managers = Array.new(3) { create(:membership, organization: company, roles: %w[client_manager]) }
    client_x, client_y = in_company do
      [ AllocationClient.create!(name: "Cliente X"), AllocationClient.create!(name: "Cliente Y") ].tap do |x, y|
        x.managers << managers[0] << managers[1]
        y.managers << managers[2]
      end
    end
    in_company { employment.revisions.sole.update_column(:allocation_client_id, client_x.id) }
    item("Aprovação do cliente", kind: "approval", responsible_role: "client_manager")

    instance = start
    approval = items_of(instance)["Aprovação do cliente"]
    expect(approval.responsible_membership_ids).to contain_exactly(managers[0].id, managers[1].id)

    in_company do
      employment.revisions.create!(effective_on: Date.current, position: position, unit: caxias, allocation_client: client_y,
        salary_cents: 200_000, salary_unit: "month", reason: "transfer", created_by: hr_user)
    end

    expect(approval.reload.responsible_membership_ids).to eq([ managers[2].id ])
    expect(in_company { instance.events.pluck(:action) }).to include("client_changed")
  end

  it "blocks an item until all it depends on are resolved, ignoring those left out (RN-06-040, RN-06-042, CA-06-004)" do
    rg = item("RG validado")
    proof = item("Comprovante validado")
    out = item("Só em Bento", conditions: { "unit_ids" => [ bento.id ] })
    item("Encaminhar à contabilidade", kind: "forward", config: { "record" => true }, depends_on_item_ids: [ rg.id, proof.id, out.id ])

    instance = start
    items = items_of(instance)
    forward = items["Encaminhar à contabilidade"]
    expect(forward).to be_blocked
    expect(in_company { forward.depends_on.map(&:title) }).to contain_exactly("RG validado", "Comprovante validado")

    in_company do
      expect(Processes::ItemActions.new(items["RG validado"], by: hr_user).complete(comment: "Conferido")).to be(true)
      perform_enqueued_jobs(only: Processes::UnblockItemsJob)
    end
    expect(forward.reload).to be_blocked

    in_company do
      Processes::ItemActions.new(items["Comprovante validado"], by: hr_user).skip(reason: "Já apresentado na entrevista")
      perform_enqueued_jobs(only: Processes::UnblockItemsJob)
    end
    expect(forward.reload).to be_pending
    expect(items["RG validado"].reload.result).to eq("comment" => "Conferido")
  end

  it "skips a required item only with a reason, and rejects an approval only with one (RN-06-052)" do
    item("Exame")
    item("Aprovação", kind: "approval")
    items = items_of(start)

    in_company do
      skip = Processes::ItemActions.new(items["Exame"], by: hr_user)
      expect(skip.skip(reason: " ")).to be(false)
      expect(items["Exame"].errors[:base]).to include("Um item obrigatório só é dispensado com justificativa")

      reject = Processes::ItemActions.new(items["Aprovação"], by: hr_user)
      expect(reject.reject(reason: "")).to be(false)
      expect(reject.reject(reason: "Salário fora da faixa")).to be(true)
    end
    expect(items["Aprovação"].reload).to have_attributes(status: "rejected", result: { "reason" => "Salário fora da faixa" })
  end

  it "waits for the HR to end, or ends by itself in the automatic mode (RN-06-053)" do
    item("Única")

    confirm = start
    in_company do
      Processes::ItemActions.new(confirm.items.sole, by: hr_user).complete
      perform_enqueued_jobs(only: Processes::UnblockItemsJob)
    end
    expect(confirm.reload).to be_open
    expect(in_company { confirm.ready_to_complete? }).to be(true)
    expect(in_company { Processes::Complete.call(confirm, by: hr_user) }).to be(true)
    expect(confirm.reload).to have_attributes(status: "completed", completed_by: hr_user)

    automatic = start(mode: "automatic")
    in_company do
      Processes::ItemActions.new(automatic.items.sole, by: hr_user).complete
      perform_enqueued_jobs(only: Processes::UnblockItemsJob)
    end
    expect(automatic.reload).to be_completed
  end

  it "moves the dates with the reference, except the ones set by hand or resolved (RN-06-027, CA-06-007)" do
    item("A", due_anchor: "work_start", due_offset_days: -1)
    item("B", due_anchor: "work_start", due_offset_days: -1)
    item("C", due_anchor: "work_start", due_offset_days: -1)
    instance = start(anchors: { "work_start" => Date.new(2026, 12, 1) })
    items = items_of(instance)
    items["B"].update!(due_on: Date.new(2026, 11, 25), due_manually_set: true)
    in_company { Processes::ItemActions.new(items["C"], by: hr_user).complete }

    in_company { Processes::ChangeAnchors.call(instance, { "work_start" => Date.new(2026, 12, 8) }, by: hr_user) }

    expect(items.values.map { |each| [ each.title, each.reload.due_on ] }).to eq(
      [ [ "A", Date.new(2026, 12, 7) ], [ "B", Date.new(2026, 11, 25) ], [ "C", Date.new(2026, 11, 30) ] ]
    )
    expect(instance.reload.anchor_date("work_start")).to eq(Date.new(2026, 12, 8))
  end

  it "takes the acknowledgement's PDF in use at the start (P-06-17)" do
    acknowledgement = item("Regulamento", kind: "acknowledgement", responsible_role: "employee")
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF-1.4"), filename: "r.pdf", content_type: "application/pdf")
    FileScan.create!(blob: blob, status: "clean")
    material = in_company { acknowledgement.materials.create!(version: 1, uploaded_by: hr_user, file: blob) }

    copy = items_of(start)["Regulamento"]

    expect(copy).to have_attributes(responsible_membership_ids: [ profile.membership_id ], config: { "material_id" => material.id })
  end

  it "tells who answers for an overdue item and the HR, once (RN-06-028)" do
    manager = create(:membership, organization: company, roles: %w[manager])
    department = in_company { Department.create!(name: "Produção", unit: caxias).tap { |each| each.managers << manager } }
    in_company { employment.revisions.sole.update_column(:department_id, department.id) }
    item("Apresentar a equipe", responsible_role: "manager", due_anchor: "process_start", due_offset_days: 1)
    instance = start

    travel_to(3.days.from_now) do
      expect { Processes::OverdueItemsJob.perform_now }.to change(Notification, :count).by(2)
      expect { Processes::OverdueItemsJob.perform_now }.not_to change(Notification, :count)
    end
    expect(Notification.where(notification_type: "processes.task_overdue").pluck(:recipient_user_id)).to contain_exactly(manager.user_id, hr_user.id)
    expect(in_company { instance.items.sole.overdue_notified_on }).to be_present
  end
end
