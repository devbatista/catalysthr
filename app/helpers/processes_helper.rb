# The page of a process under way (spec 06, D-641), as in the prototype's checklist: the
# item, who answers for it, the date and the status.
module ProcessesHelper
  STATUS_PILLS = { "open" => "pill-info", "completed" => "pill-ok", "cancelled" => "pill-mute" }.freeze
  ITEM_PILLS = { "blocked" => "pill-mute", "pending" => "pill-warn", "submitted" => "pill-info",
    "correction_requested" => "pill-warn", "done" => "pill-ok", "skipped" => "pill-mute", "approved" => "pill-ok",
    "rejected" => "pill-bad", "sent" => "pill-info", "received" => "pill-ok" }.freeze
  # The people the HR may choose as responsible, besides the current ones (RN-06-021).
  RESPONSIBLE_ROLES = %w[hr_admin hr_analyst manager client_manager].freeze

  # "Integração de Ana Souza"
  def process_title(instance)
    t("processes.title", kind: t("process_templates.kinds.#{instance.kind}"), person: instance.subject.worker_profile.display_name)
  end

  def process_status_pill(instance)
    tag.span(t("processes.statuses.#{instance.status}"), class: "pill #{STATUS_PILLS.fetch(instance.status)}")
  end

  # The status, and "Atrasado" for an open item past its date (RN-06-028).
  # The firm an item may be sent to now (D-652).
  def linked_firm
    return @linked_firm if defined?(@linked_firm)

    @linked_firm = Processes::FirmForward.linked_firm(Current.company)
  end

  # The firm's own words for where a forward is (D-652).
  def firm_forward_pill(item)
    tag.span(t("panel.firm_panel.forwards.statuses.#{item.status}"), class: "pill #{ITEM_PILLS.fetch(item.status)}")
  end

  def process_item_pills(item, today)
    pills = [ tag.span(t("processes.item_statuses.#{item.status}"), class: "pill #{ITEM_PILLS.fetch(item.status)}") ]
    pills << tag.span(t("processes.overdue"), class: "pill pill-bad") if item.overdue?(today)
    safe_join(pills)
  end

  def responsible_names(item, people)
    names = item.responsible_membership_ids.filter_map { |id| people[id]&.user&.name }
    names.any? ? names.to_sentence : t("processes.nobody")
  end

  def process_item_due(item)
    item.due_on ? l(item.due_on, format: "%d/%m/%Y") : t("processes.no_due")
  end

  # The process's dates, such as "Início do trabalho: 15/11/2026" (RN-06-025).
  def process_anchor_dates(instance)
    ProcessTemplateItemDefinition::ANCHORS.fetch(instance.kind).filter_map do |anchor|
      date = instance.anchor_date(anchor)
      [ t("process_templates.anchors.#{anchor}"), date ? l(date, format: "%d/%m/%Y") : t("processes.no_date") ]
    end
  end

  # [label, membership id]: the company's HR, managers and client managers, the process's
  # HR (consultants included), the person and the current ones.
  def responsible_options(instance, item)
    company_people = Membership.with_access.where(organization: instance.company)
      .where("memberships.roles && ARRAY[?]::varchar[]", RESPONSIBLE_ROLES)
    ids = company_people.pluck(:id)
    ids += Processes::HrScope.new(instance.company).memberships_for(unit_id: instance.unit_id, kind: instance.kind).map(&:id)
    ids << instance.subject.worker_profile.membership_id if instance.employment
    ids += item.responsible_membership_ids
    Membership.where(id: ids.uniq).includes(:user).sort_by { |membership| membership.user.name.to_s }.map do |membership|
      roles = membership.roles.map { |role| t("processes.member_roles.#{role}", default: role) }.join(", ")
      [ "#{membership.user.name} (#{roles})", membership.id ]
    end
  end

  # One line of the history (RN-06-051).
  def process_event_text(event)
    details = event.details.symbolize_keys
    details[:fields] = Array(details[:fields]).map { |field| t("processes.fields.#{field}", default: field) }.join(", ")
    details[:from] = details[:from] ? l(Date.iso8601(details[:from]), format: "%d/%m/%Y") : t("processes.no_due")
    details[:to] = details[:to] ? l(Date.iso8601(details[:to]), format: "%d/%m/%Y") : t("processes.no_due")
    t("processes.events.#{event.action}", **details, default: event.action)
  end
end
