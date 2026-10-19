module Admin
  # The symbolic fee a partner pays until the first active employee in the portfolio
  # (RN-19-035, D-612): a single value with versions like the prices (D-611).
  class PreActivationPricesController < BillingController
    def new
      authorize! :create, PreActivationPrice
      @price = PreActivationPrice.new(valid_from: Date.current, monthly_price_cents: PreActivationPrice.latest&.monthly_price_cents)
    end

    def create
      authorize! :create, PreActivationPrice
      @price = PreActivationPrice.new(params.expect(pre_activation_price: %i[monthly_price valid_from]).merge(created_by: current_user))

      if @price.save
        redirect_to admin_plans_path, notice: t(".created", date: l(@price.valid_from))
      else
        render :new, status: :unprocessable_content
      end
    end
  end
end
