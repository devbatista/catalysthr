module AccountingFirms
  # The company's HR administrator ends the link, or cancels a pending request
  # (RN-02-073, D-590). The accountants lose the company at their next request: the
  # selector only lists active links, and whoever is left without access to the brand
  # is signed out (D-586, ApplicationController#check_area_access).
  class Unlink
    def self.call(**)
      new(**).call
    end

    def initialize(link:, by:)
      @link = link
      @by = by
    end

    def call
      action = @link.pending? ? "accounting_firm_link_cancelled" : "accounting_firm_unlinked"
      @link.with_lock do
        raise ActiveRecord::RecordNotFound unless @link.status.in?(AccountingFirmCompany::OPEN_STATUSES)

        @link.update!(status: "ended", ended_at: Time.current)
      end
      AccessEvent.record!(kind: "admin", action: action, user: @by, subject: @link, company: @link.company)
      @link
    end
  end
end
