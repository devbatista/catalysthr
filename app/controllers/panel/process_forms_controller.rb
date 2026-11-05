module Panel
  # A form item in the panel (RN-06-030, RN-06-031, D-649): the HR fills it in the person's
  # name, corrects, gives it back with a reason and applies it to the record. The page shows
  # the answers, so it asks for the password and turns each sensitive value into an access
  # event (RN-02-052, RN-05-020). The bank data of an open admission don't need the payroll
  # module, as the salary (P-03-16, D-649).
  class ProcessFormsController < BaseController
    include SensitiveAccess

    SECTIONS = { "documents" => :read_personal, "health" => :read_health, "pay" => :read_pay }.freeze

    before_action :require_current_company
    before_action :load_item

    def edit
      authorize! :adjust, @instance
      reveal
    end

    def update
      authorize! :adjust, @instance
      reveal
      return if performed?

      if @form.save(form_params)
        redirect_to edit_process_item_form_path(@instance, @item), notice: t(".saved")
      else
        redirect_to process_path(@instance, anchor: "items"), alert: @form.errors.to_sentence
      end
    end

    def apply
      authorize! :adjust, @instance
      reveal
      return if performed?

      if @form.apply(form_params)
        redirect_to process_path(@instance, anchor: "items"), notice: t(".applied")
      else
        @item.reload
        render :edit, status: :unprocessable_content
      end
    end

    # Back to the person, with the reason they see (D-649).
    def give_back
      authorize! :adjust, @instance
      if @form.give_back(reason: params[:reason])
        redirect_to process_path(@instance, anchor: "items"), notice: t(".given_back")
      else
        redirect_to edit_process_item_form_path(@instance, @item), alert: @form.errors.to_sentence
      end
    end

    private

    # Out of the person's reach answers 404 (RN-03-006).
    def load_item
      @instance = ProcessInstance.accessible_by(current_ability, :read).find(params[:process_id])
      @item = @instance.items.where(kind: "form").find(params[:item_id])
      @form = Processes::FormItem.new(@item, by: current_user)
    end

    def reveal
      profile = @form.schema.profile
      needed = @form.schema.needed_sections
      needed.each { |section| authorize! SECTIONS.fetch(section), profile unless section == "pay" && @instance.admission? }
      reveal_all_sections(needed)
    end

    # Free keys by design: FormSchema#clean keeps only what the item asks.
    def form_params
      params.fetch(:form, {}).to_unsafe_h
    end
  end
end
