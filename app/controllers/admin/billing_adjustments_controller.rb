module Admin
  # Manual adjustments of a contract's next invoices (RN-19-070, RN-19-071, CA-19-009,
  # D-621): the finance team and the superadmin launch them on the client's page, with a
  # reason; above 20% of the next invoice, the finance team's wait for the superadmin, who
  # approves them here. The support reads (spec 19, section 6).
  class BillingAdjustmentsController < BillingController
    RECENT = 50

    def index
      authorize! :read, BillingAdjustment
      @pending = BillingAdjustment.pending.includes(:created_by, :invoice_lines, billing_account: :owner).order(:created_at)
      @recent = BillingAdjustment.where.not(status: "pending").includes(:created_by, :invoice_lines, billing_account: :owner)
        .newest_first.limit(RECENT)
    end

    def new
      authorize! :create, BillingAdjustment
      @account = BillingAccount.find(params[:client_id])
      @adjustment = @account.billing_adjustments.new(kind: params[:kind].presence_in(BillingAdjustment::KINDS) || "discount", cycles: 1)
    end

    def create
      authorize! :create, BillingAdjustment
      @account = BillingAccount.find(params[:client_id])
      @adjustment = Billing::Adjustments.launch(@account, adjustment_params, by: current_user)

      if @adjustment.persisted?
        redirect_to admin_client_path(@account), notice: t(@adjustment.pending? ? ".pending" : ".approved")
      else
        render :new, status: :unprocessable_content
      end
    end

    def approve
      adjustment = BillingAdjustment.find(params[:id])
      authorize! :approve, adjustment
      notice = Billing::Adjustments.approve(adjustment, by: current_user) ? t(".approved") : t(".not_pending")
      redirect_back_or_to admin_adjustments_path, notice: notice
    end

    def cancel
      adjustment = BillingAdjustment.find(params[:id])
      authorize! :cancel, adjustment
      notice = Billing::Adjustments.cancel(adjustment, by: current_user) ? t(".cancelled") : t(".not_cancellable")
      redirect_back_or_to admin_adjustments_path, notice: notice
    end

    private

    # Only the fields of the kind chosen; the others stay empty.
    def adjustment_params
      attributes = params.expect(adjustment: %i[kind value percent cycles overage_scope reason])
      case attributes[:kind]
      when "discount" then attributes.except(:overage_scope)
      when "credit" then attributes.except(:percent, :overage_scope).merge(cycles: 1)
      else attributes.except(:value, :percent).merge(cycles: 1)
      end
    end
  end
end
