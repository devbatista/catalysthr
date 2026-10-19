module Admin
  # A new monthly price of an add-on (RN-19-013), with versions like the plans' (D-611).
  # The add-on is created with its first price.
  class AddOnPricesController < BillingController
    before_action :load_add_on

    def new
      authorize! :create, AddOnPrice
      @price = AddOnPrice.new(add_on: @add_on, valid_from: Date.current, monthly_price_cents: @add_on.latest_price&.monthly_price_cents)
    end

    def create
      authorize! :create, AddOnPrice
      @price = AddOnPrice.new(params.expect(add_on_price: %i[monthly_price valid_from]).merge(add_on: @add_on, created_by: current_user))

      if save_price
        redirect_to admin_plans_path, notice: t(".created", add_on: t("add_ons.names.#{@add_on.code}"), date: l(@price.valid_from))
      else
        render :new, status: :unprocessable_content
      end
    end

    private

    def load_add_on
      raise ActiveRecord::RecordNotFound unless params[:add_on_code].in?(AddOn::CODES)

      @add_on = AddOn.find_or_initialize_by(code: params[:add_on_code])
    end

    def save_price
      return false unless @price.valid?

      AddOn.transaction do
        @add_on.save! if @add_on.new_record?
        @price.save!
      end
      true
    end
  end
end
