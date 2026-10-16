module Panel
  module PartnerPanel
    # The partner's own brand, edited by the partner's administrator (spec 01, section 6).
    class BrandsController < BaseController
      include BrandEditing

      before_action { @brand = partner.brand || raise(ActiveRecord::RecordNotFound) }

      def edit
        authorize! :update, @brand
      end

      def update
        authorize! :update, @brand
        if save_brand(@brand)
          redirect_to edit_partner_brand_path, notice: t("brands.updated")
        else
          render :edit, status: :unprocessable_content
        end
      end
    end
  end
end
