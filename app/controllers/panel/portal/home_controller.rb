module Panel
  module Portal
    # The portal's start (spec 16, RN-16-020, D-429, D-645): "Minha equipe" for managers,
    # the pending items with their dates and the progress of the person's processes. The
    # blocks of time tracking, notices, requests and the payslip come with their specs; an
    # empty block does not show.
    class HomeController < BaseController
      def index
        authorize! :read, :portal
        @team = TeamOverview.new(current_membership) if portal_manager?
        @processes = current_profile ? open_processes : []
      end

      private

      # The admission's and the onboarding's progress (spec 06, spec 07).
      def open_processes
        ProcessInstance.open.where(subject: current_profile.employments, kind: %w[admission onboarding])
          .includes(:items).order(:created_at).to_a
      end
    end
  end
end
