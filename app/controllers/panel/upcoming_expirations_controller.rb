module Panel
  # "Vencimentos", opened by the HR panel's indicator (RN-17-010, D-658): the documents and
  # the experience periods ending from today to 30 days, the nearest first. The expired
  # documents stay in the documents' expirations (RN-08-031).
  class UpcomingExpirationsController < BaseController
    include DashboardLists

    def index
      authorize! :read, :hr_dashboard
      panel = dashboard_panel
      @rows = panel.expirations
      @today = @filter.today
      @until = @today + Dashboards::HrPanel::EXPIRATION_DAYS
    end
  end
end
