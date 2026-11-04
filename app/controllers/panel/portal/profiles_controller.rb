module Panel
  module Portal
    # "Meus dados" (spec 16, RN-16-011): the person's employment and contact, without
    # sensitive data. Asking for a change (D-210) comes with the requests (spec 09).
    class ProfilesController < BaseController
      before_action :require_profile

      def show
        authorize! :read, :portal
        @employments = current_profile.employments.includes(revisions: %i[position unit department]).sort_by { |each| each.open? ? 0 : 1 }
      end
    end
  end
end
