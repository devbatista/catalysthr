module Panel
  # The items of a process under way (spec 06, D-641). Who answers for an item, or the HR,
  # resolves it: a task done, an approval, a forward recorded by the HR (RN-06-066). Only the
  # HR adds, changes, moves, removes and skips items, each change in the history
  # (RN-06-051, RN-06-052). A closed process is read only.
  class ProcessItemsController < BaseController
    before_action :require_current_company
    before_action :load_instance
    before_action :load_item, except: %i[new create]

    def new
      authorize! :adjust, @instance
      return closed_redirect unless @instance.open?

      kind = params[:kind].presence_in(ProcessItem::ADDABLE_KINDS) || "task"
      @item = @instance.items.build(kind: kind, required: true, responsible_role: "hr")
    end

    def create
      authorize! :adjust, @instance
      return closed_redirect unless @instance.open?

      @item = @instance.items.build(kind: params.dig(:item, :kind).presence_in(ProcessItem::ADDABLE_KINDS), status: "pending",
        position: (@instance.items.maximum(:position) || 0) + 1)
      @item.assign_attributes(item_params.slice(:title, :instructions, :required, :responsible_role))
      assign_due(item_params[:due_on])
      assign_role_responsibles

      if @item.save
        Processes::Events.record(@instance, "item_added", by: current_user, item: @item, title: @item.title)
        Processes::Notices.assigned([ @item ])
        redirect_to process_path(@instance, anchor: "items"), notice: t(".created")
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize! :adjust, @instance
      closed_redirect unless @item.open? && @instance.open?
    end

    # Title, instructions, required, the date set by hand (RN-06-027) and the people
    # responsible (RN-06-021).
    def update
      authorize! :adjust, @instance
      return closed_redirect unless @item.open? && @instance.open?

      attributes = item_params
      @item.assign_attributes(attributes.slice(:title, :instructions, :required))
      @item.required = true if Admissions::Aso.required_item?(@item)
      assign_due(attributes[:due_on]) if attributes.key?(:due_on)
      people_before = @item.responsible_membership_ids
      assign_people(attributes[:responsible_membership_ids]) if attributes.key?(:responsible_membership_ids)

      if @item.responsible_membership_ids.empty?
        @item.errors.add(:responsible_membership_ids, :blank)
        return render(:edit, status: :unprocessable_content)
      end
      changes = @item.changed - %w[responsible_membership_ids responsible_fallback overdue_notified_on due_manually_set]
      if @item.save
        record_update(changes, people_before)
        redirect_to process_path(@instance, anchor: "items"), notice: t(".updated")
      else
        render :edit, status: :unprocessable_content
      end
    end

    # Only an item not yet resolved; the ones that waited for it may be freed (RN-06-040).
    def destroy
      authorize! :adjust, @instance
      return closed_redirect if @item.resolved? || !@instance.open? || Admissions::Aso.required_item?(@item)

      @item.transaction do
        Processes::Events.record(@instance, "item_removed", by: current_user, title: @item.title)
        @item.destroy!
        Processes::Unblock.call(@instance)
      end
      redirect_to process_path(@instance, anchor: "items"), notice: t(".destroyed")
    end

    def move
      authorize! :adjust, @instance
      return closed_redirect unless @instance.open?

      items = @instance.items.to_a
      index = items.index(@item)
      neighbor = items[params[:direction] == "up" ? index - 1 : index + 1] if index
      if neighbor && (params[:direction] == "down" || index.positive?)
        @item.transaction do
          position = @item.position
          @item.update!(position: neighbor.position)
          neighbor.update!(position: position)
          Processes::Events.record(@instance, "item_moved", by: current_user, item: @item, title: @item.title)
        end
      end
      redirect_to process_path(@instance, anchor: "items")
    end

    def done
      authorize! :act, @item
      resolve(item_actions.complete(comment: params[:comment]))
    end

    def approve
      authorize! :act, @item
      resolve(item_actions.approve)
    end

    def reject
      authorize! :act, @item
      resolve(item_actions.reject(reason: params[:reason]))
    end

    # Recorded by the HR (RN-06-066, P-06-18).
    def forward
      authorize! :adjust, @instance
      receipt = params[:receipt]
      receipt = nil unless receipt.is_a?(ActionDispatch::Http::UploadedFile)
      resolve(item_actions.forward(sent_on: params[:sent_on], receipt: receipt))
    end

    def reopen
      authorize! :adjust, @instance
      resolve(item_actions.reopen)
    end

    def skip
      authorize! :adjust, @instance
      resolve(item_actions.skip(reason: params[:skipped_reason]))
    end

    # The forward's receipt, to the HR, only once clean (P-05-30). The application serves it,
    # so the bucket's addresses never reach the browser (RN-01-014).
    def receipt
      authorize! :adjust, @instance
      serve(@item.forward_receipt.attached? ? @item.forward_receipt.blob : nil)
    end

    # The acknowledgement's PDF the process took at the start (P-06-17).
    def material
      authorize! :act, @item unless can?(:adjust, @instance)
      material = @item.material
      serve(material&.clean? ? material.file.blob : nil)
    end

    private

    # Out of the person's reach answers 404 (RN-03-006).
    def load_instance
      @instance = ProcessInstance.accessible_by(current_ability, :read).find(params[:process_id])
    end

    def load_item
      @item = @instance.items.find(params[:id])
    end

    def item_actions
      Processes::ItemActions.new(@item, by: current_user)
    end

    def resolve(done)
      if done
        redirect_to process_path(@instance, anchor: "items"), notice: t("panel.process_items.resolved.#{@item.status}")
      else
        redirect_to process_path(@instance, anchor: "items"), alert: @item.errors.full_messages.to_sentence
      end
    end

    def serve(blob)
      raise ActiveRecord::RecordNotFound unless blob&.file_scan&.clean?

      response.headers["Cache-Control"] = "private, no-store"
      send_data blob.download, type: blob.content_type, disposition: :inline, filename: blob.filename.to_s
    end

    def closed_redirect
      redirect_to process_path(@instance, anchor: "items"), alert: t("panel.process_items.closed")
    end

    def item_params
      params.expect(item: [ :title, :instructions, :required, :responsible_role, :due_on, { responsible_membership_ids: [] } ])
    end

    # A date set here is kept when the reference date changes (RN-06-027, P-06-08).
    def assign_due(value)
      date = parse_date(value)
      return if date == @item.due_on

      @item.assign_attributes(due_on: date, due_manually_set: true, overdue_notified_on: nil)
    end

    def parse_date(value)
      Date.iso8601(value.to_s) if value.present?
    rescue Date::Error
      nil
    end

    def assign_role_responsibles
      return unless @item.responsible_role.in?(ProcessTemplateItemDefinition::ROLES) && @instance.employment

      assignment = Processes::Responsibles.new(company: Current.company, employment: @instance.employment, kind: @instance.kind,
        starter: current_membership).for(@item.responsible_role)
      @item.assign_attributes(responsible_membership_ids: assignment.membership_ids, responsible_fallback: assignment.fallback)
    end

    # Only the people offered on the form (helpers/processes_helper.rb).
    def assign_people(ids)
      allowed = helpers.responsible_options(@instance, @item).map(&:last)
      chosen = Array(ids).compact_blank & allowed
      @item.assign_attributes(responsible_membership_ids: chosen, responsible_fallback: false) if chosen.sort != @item.responsible_membership_ids.sort
    end

    def record_update(changes, people_before)
      if @item.responsible_membership_ids != people_before
        Processes::Events.record(@instance, "responsible_changed", by: current_user, item: @item, title: @item.title)
        Processes::Notices.assigned([ @item ]) if @item.pending?
      end
      return if changes.empty?

      Processes::Events.record(@instance, "item_updated", by: current_user, item: @item, title: @item.title, fields: changes)
    end

    def current_membership
      Membership.with_access.find_by(user: current_user, organization: Current.company)
    end
  end
end
