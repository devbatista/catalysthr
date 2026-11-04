# What the employee has to do, for the portal's start and the tabs' counts (spec 16,
# RN-16-012, RN-16-020, D-645): documents to send or fix (asked by the HR, a correction,
# refused by the scan, expiring or expired), acknowledgments waiting and the process items
# assigned to them, the nearest date first. Self-evaluation and the time sheet come with
# their specs.
class EmployeePendings
  Pending = Data.define(:kind, :title, :detail, :due_on, :path, :tone)

  include Rails.application.routes.url_helpers

  def initialize(profile, membership)
    @profile = profile
    @membership = membership
  end

  def all
    @all ||= (documents + acknowledgments + items).sort_by { |pending| [ pending.due_on || Date.new(9999), pending.title ] }
  end

  def documents_count
    all.count { |pending| pending.kind.in?(%i[document acknowledgment]) }
  end

  private

  def documents
    return [] unless @profile

    Document.for_employee.where(worker_profile: @profile).preload(:document_type, :source_ref, :versions).filter_map do |document|
      latest = document.latest_version
      name = document.document_type.name
      if latest&.status.in?(%w[correction_requested rejected_by_scan])
        detail = latest.rejected_by_scan? ? I18n.t("portal.pendings.rejected_by_scan") : correction(latest)
        Pending.new(:document, I18n.t("portal.pendings.fix", document: name), detail, nil, portal_document_path(document), :bad)
      elsif latest.nil?
        request = document.source_ref if document.source_ref_type == "DocumentRequest"
        Pending.new(:document, I18n.t("portal.pendings.send", document: name), request&.message, request&.due_on,
          portal_document_path(document), :warn)
      elsif document.status.in?(%w[expiring expired]) && latest.approved?
        Pending.new(:document, I18n.t("portal.pendings.renew", document: name),
          I18n.t("portal.pendings.expires.#{document.status}", date: I18n.l(document.expires_on)), document.expires_on,
          portal_document_path(document), document.status_expired? ? :bad : :warn)
      end
    end
  end

  def acknowledgments
    return [] unless @profile

    Acknowledgment.awaiting.where(worker_profile: @profile).includes(:publication, document: :document_type).map do |acknowledgment|
      title = acknowledgment.publication&.title || acknowledgment.document.document_type.name
      Pending.new(:acknowledgment, I18n.t("portal.pendings.acknowledge", title: title), nil, acknowledgment.due_on,
        portal_document_path(acknowledgment.document_id), :warn)
    end
  end

  def items
    return [] unless @membership

    # A document item with a correction already shows as its document's pending.
    ProcessItem.where("? = ANY(responsible_membership_ids)", @membership.id).where(status: "pending",
      kind: Panel::Portal::ProcessItemsController::KINDS).joins(:instance).merge(ProcessInstance.open).includes(:instance).map do |item|
      Pending.new(:item, item.title, I18n.t("process_templates.kinds.#{item.instance.kind}"), item.due_on, portal_item_path(item),
        item.overdue? ? :bad : :info)
    end
  end

  def correction(version)
    reason = I18n.t("documents.correction_reasons.#{version.correction_reason}")
    version.correction_note ? "#{reason}: #{version.correction_note}" : reason
  end
end
