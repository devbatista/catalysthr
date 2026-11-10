module Admin
  # The assisted import (RN-18-060, D-466, D-666): the support or the superadmin finds the
  # company, direct or of a partner, sees whether its HR administrator authorized it, and opens
  # its imports.
  class AssistedImportsController < BaseController
    before_action -> { head :not_found unless FeatureFlags.enabled?(FeatureFlags::DATA_IMPORTS) }

    def index
      authorize! :assist, :data_imports
      @query = params[:q].to_s.strip
      @companies = @query.length >= 3 ? Company.merge(Company.matching(@query)).order(:name).limit(20).to_a : []
      @authorizations = @companies.to_h { |company| [ company.id, ActsAsTenant.with_tenant(company) { AssistedImportAuthorization.current } ] }
    end
  end
end
