module Panel
  # One block of the HR panel (spec 17, section 4.2, D-657, D-658). The page asks each block
  # in its own request, in parallel, so a slow one never holds the others (RN-17-090,
  # CA-17-012). Each block stays 60 seconds in the cache, by company, person and filter, and
  # says when it was made; "Atualizar" asks it again (RN-17-091).
  class DashboardBlocksController < BaseController
    BLOCKS = %w[indicators pending_by_unit upcoming activity usage].freeze
    CACHE_FOR = 60.seconds

    before_action :require_flag

    def show
      authorize! :read, :hr_dashboard
      block = params[:block].presence_in(BLOCKS) or return head(:not_found)
      return head(:not_found) if block == "usage" && !Dashboards::Usage.shown?(current_ability, Current.company)

      filter = Dashboards::Filter.new(current_ability, Current.company, unit_id: params[:unit_id], client_id: params[:client_id])
      key = [ "dashboards/hr", block, *filter.cache_key(current_user) ]
      cached = Rails.cache.fetch(key, expires_in: CACHE_FOR, force: params[:refresh].present?) do
        { "html" => render_to_string(partial: "panel/dashboards/blocks/#{block}", locals: locals_for(block, filter)),
          "at" => Time.current.to_i }
      end
      response.headers["X-Generated-At"] = cached.fetch("at").to_s
      response.headers["Cache-Control"] = "no-store"
      # The HTML was rendered by the block's own partial, already escaped.
      render html: cached.fetch("html").html_safe, layout: false
    end

    private

    def require_flag
      head :not_found unless FeatureFlags.enabled?(FeatureFlags::DASHBOARDS) && Current.company
    end

    def locals_for(block, filter)
      panel = Dashboards::HrPanel.new(filter)
      block == "usage" ? { usage: Dashboards::Usage.new(Current.company, filter.today) } : { panel: panel }
    end
  end
end
