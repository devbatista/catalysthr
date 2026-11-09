# The lists the HR panel's indicators open (RN-17-002, D-658): with the same query and the
# panel's filter, so the number of the list is the indicator's (P-17-01). They come with
# the panel's flag.
module DashboardLists
  extend ActiveSupport::Concern

  LIMIT = 200

  included do
    before_action :require_dashboards
  end

  private

  def require_dashboards
    head :not_found unless FeatureFlags.enabled?(FeatureFlags::DASHBOARDS) && Current.company
  end

  def dashboard_panel
    @filter = Dashboards::Filter.new(current_ability, Current.company, unit_id: params[:unit_id], client_id: params[:client_id])
    Dashboards::HrPanel.new(@filter)
  end
end
