module Panel
  # The page of a process under way (spec 06, RN-06-050 to RN-06-053, D-641), the one the
  # admission (spec 07) and the requests (spec 09) reuse. The HR sees every item and the
  # history, and ends or cancels the process; the manager and the client manager see only
  # the items assigned to them (RN-03-014, P-03-39).
  class ProcessesController < BaseController
    before_action :require_current_company
    before_action :load_instance
    before_action :admission_page, only: %i[complete cancel]

    def show
      authorize! :read, @instance
      @admission = Admission.find_by(employment_id: @instance.subject_id) if @instance.admission?
      @hr = can?(:adjust, @instance)
      @items = @instance.items.includes(:depends_on, forward_receipt_attachment: { blob: :file_scan }).to_a
      @items = @items.select { |item| can?(:act, item) } unless @hr
      @people = Membership.where(id: @items.flat_map(&:responsible_membership_ids)).includes(:user).index_by(&:id)
      @events = @hr ? @instance.events.includes(:actor).reverse : []
    end

    # The HR's confirmation, once every required item is resolved (RN-06-053, D-641).
    def complete
      authorize! :adjust, @instance
      if Processes::Complete.call(@instance, by: current_user)
        redirect_to process_path(@instance), notice: t(".completed")
      else
        redirect_to process_path(@instance), alert: t(".not_ready")
      end
    end

    def cancel
      authorize! :adjust, @instance
      if Processes::Complete.cancel(@instance, by: current_user, reason: params[:cancel_reason])
        redirect_to process_path(@instance), notice: t(".cancelled")
      else
        redirect_to process_path(@instance), alert: t(".cancel_reason_blank")
      end
    end

    private

    # Out of the person's reach answers 404 (RN-03-006, CA-03-010).
    def load_instance
      @instance = ProcessInstance.accessible_by(current_ability, :read).find(params[:id])
    end

    # An admission ends and is cancelled by its own rules (RN-07-080, RN-07-090), never here:
    # the employment and the access go with it.
    def admission_page
      return unless @instance.admission? && (admission = Admission.find_by(employment_id: @instance.subject_id))

      redirect_to admission_path(admission), alert: t("panel.processes.admission_rules")
    end
  end
end
