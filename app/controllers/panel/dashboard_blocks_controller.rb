module Panel
  # One block of a panel (spec 17, D-657): the HR's (section 4.2, D-658) or the manager's
  # (section 4.3, D-659). The page asks each block in its own request, in parallel, so a slow
  # one never holds the others (RN-17-090, CA-17-012). Each block stays 60 seconds in the
  # cache, by company, person and filter, and says when it was made; "Atualizar" asks it
  # again (RN-17-091).
  class DashboardBlocksController < BaseController
    HR_BLOCKS = %w[indicators pending_by_unit upcoming activity usage].freeze
    MANAGER_BLOCKS = %w[team waiting team_expiring probations].freeze
    CACHE_FOR = 60.seconds

    before_action :require_flag

    def show
      block = params[:block].presence_in(HR_BLOCKS + MANAGER_BLOCKS)
      if block.nil?
        authorize! :read, :panel_home
        head :not_found
      elsif MANAGER_BLOCKS.include?(block)
        authorize! :read, :manager_dashboard
        membership = Membership.with_access.find_by!(user: current_user, organization: Current.company)
        overview = TeamOverview.new(membership, unit_id: params[:unit_id])
        key = [ "dashboards/manager", block, Current.company.id, current_user.id, overview.unit_id || "-" ]
        respond_with_block(key, "manager_#{block}", overview: overview)
      else
        authorize! :read, :hr_dashboard
        return head(:not_found) if block == "usage" && !Dashboards::Usage.shown?(current_ability, Current.company)

        filter = Dashboards::Filter.new(current_ability, Current.company, unit_id: params[:unit_id], client_id: params[:client_id])
        locals = block == "usage" ? { usage: Dashboards::Usage.new(Current.company, filter.today) } : { panel: Dashboards::HrPanel.new(filter) }
        respond_with_block([ "dashboards/hr", block, *filter.cache_key(current_user) ], block, **locals)
      end
    end

    private

    def require_flag
      head :not_found unless FeatureFlags.enabled?(FeatureFlags::DASHBOARDS) && Current.company
    end

    def respond_with_block(key, partial, **locals)
      cached = Rails.cache.fetch(key, expires_in: CACHE_FOR, force: params[:refresh].present?) do
        { "html" => render_to_string(partial: "panel/dashboards/blocks/#{partial}", locals: locals), "at" => Time.current.to_i }
      end
      response.headers["X-Generated-At"] = cached.fetch("at").to_s
      response.headers["Cache-Control"] = "no-store"
      # The HTML was rendered by the block's own partial, already escaped.
      render html: cached.fetch("html").html_safe, layout: false
    end
  end
end
