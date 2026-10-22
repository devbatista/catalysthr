module Admin
  # The CatalystHR team's panel (RN-19-090 to RN-19-092, D-610, D-626): in phase 1, the
  # Revenue block, for the superadmin and the finance team, and the Clients block, also for
  # the support (P-19-28).
  class DashboardsController < BillingController
    def show
      authorize! :read, :team_panel
      @revenue = Billing::RevenueSummary.new if can?(:read, :team_panel_revenue)
      @clients = Billing::ClientsOverview.new.rows if can?(:read, :team_panel_clients)
    end
  end
end
