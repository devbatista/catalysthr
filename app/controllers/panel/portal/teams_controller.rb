module Panel
  module Portal
    # "Minha equipe" (spec 16, RN-16-030, RN-16-031, D-420, D-645): the process items
    # assigned to the manager, to resolve in the panel's page of the process, and the team's
    # documents expiring, the text only (P-08-11). The rest of the management stays in the
    # panel.
    class TeamsController < BaseController
      def show
        authorize! :read, :portal
        raise ActiveRecord::RecordNotFound unless portal_manager?

        @team = TeamOverview.new(current_membership)
      end
    end
  end
end
