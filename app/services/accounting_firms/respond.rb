module AccountingFirms
  # The firm's administrator accepts or refuses a company's request (P-02-29, D-590).
  # A refused request ends.
  class Respond
    def self.call(**)
      new(**).call
    end

    def initialize(link:, accept:, by:)
      @link = link
      @accept = accept
      @by = by
    end

    def call
      @link.with_lock do
        raise ActiveRecord::RecordNotFound unless @link.pending?

        if @accept
          @link.update!(status: "active", accepted_at: Time.current)
        else
          @link.update!(status: "ended", ended_at: Time.current)
        end
      end
      AccessEvent.record!(kind: "admin", action: @accept ? "accounting_firm_link_accepted" : "accounting_firm_link_refused",
        user: @by, subject: @link, company: @link.company)
      @link
    end
  end
end
