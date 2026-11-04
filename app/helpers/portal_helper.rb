# The portal's frame (spec 16, D-421, D-645): the tabs of the bottom bar on the phone, the
# same as a side menu on the computer, only those that apply to the person, each with the
# count of what is pending there (RN-16-012). Time tracking and requests come with their
# specs.
module PortalHelper
  PortalTab = Data.define(:key, :label, :path, :active, :count)
  TONE_PILLS = { bad: "pill-bad", warn: "pill-warn", info: "pill-info" }.freeze

  def portal_pendings
    @portal_pendings ||= EmployeePendings.new(current_profile, current_membership)
  end

  def portal_tabs
    section = portal_section
    [
      PortalTab.new(:home, t("portal.tabs.home"), portal_root_path, section == :home, portal_pendings.all.size),
      (PortalTab.new(:documents, t("portal.tabs.documents"), portal_documents_path, section == :documents, portal_pendings.documents_count) if current_profile),
      PortalTab.new(:more, t("portal.tabs.more"), portal_more_path, section == :more, 0)
    ].compact
  end

  def portal_section
    case controller_name
    when "home" then :home
    when "documents", "document_versions" then :documents
    else :more
    end
  end

  def portal_tone_pill(tone)
    TONE_PILLS.fetch(tone, "pill-mute")
  end

  # The employee's view of a document (D-280): the latest version's state, the one they
  # follow.
  def portal_document_state(document)
    latest = document.latest_version
    key, tone = if latest.nil? then [ "to_send", :warn ]
    elsif latest.status.in?(%w[correction_requested rejected_by_scan]) then [ "correction", :bad ]
    elsif latest.approved? && document.status_expired? then [ "expired", :bad ]
    elsif latest.approved? && document.status_expiring? then [ "expiring", :warn ]
    elsif latest.approved? then [ "valid", :ok ]
    else [ "in_review", :info ]
    end
    tag.span(t("portal.document_states.#{key}"), class: "pill #{tone == :ok ? "pill-ok" : portal_tone_pill(tone)}")
  end
end
