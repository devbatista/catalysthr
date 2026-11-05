module Panel
  module Portal
    # A process item assigned to the person, in the portal (spec 06, RN-06-010, RN-06-060;
    # spec 16, D-645): a task marked as done, with an optional comment; the PDF to read and
    # accept, recording the version read, the date, the IP and the browser; and the document
    # to send, through the folder; and the form, saved as a draft on the server and sent to
    # the HR, who applies it to the record (RN-06-031, D-649).
    class ProcessItemsController < BaseController
      KINDS = %w[task acknowledgement document form].freeze

      before_action :load_item

      def show
        authorize! :complete_own, @item
        @document = Document.kept.find_by(source_ref: @item) if @item.document?
        @form = Processes::FormItem.new(@item, by: current_user) if @item.form?
      end

      # "Salvar e continuar depois" or "Enviar ao RH".
      def form
        authorize! :complete_own, @item
        raise ActiveRecord::RecordNotFound unless @item.form?

        @form = Processes::FormItem.new(@item, by: current_user)
        # Free keys by design: FormSchema#clean keeps only what the item asks.
        answers = params.fetch(:form, {}).to_unsafe_h
        if params[:send_form].present?
          return redirect_to(portal_root_path, notice: t("panel.portal.process_items.form_sent")) if @form.submit(answers)

          render :show, status: :unprocessable_content
        elsif @item.status.in?(Processes::FormItem::EDITABLE) && @form.save(answers)
          redirect_to portal_item_path(@item), notice: t("panel.portal.process_items.form_saved")
        else
          redirect_to portal_item_path(@item), alert: t("processes.form.closed")
        end
      end

      def done
        authorize! :complete_own, @item
        resolve(Processes::ItemActions.new(@item, by: current_user).complete(comment: params[:comment]))
      end

      def acknowledge
        authorize! :complete_own, @item
        resolve(Processes::ItemActions.new(@item, by: current_user).acknowledge(ip: request.remote_ip, user_agent: request.user_agent))
      end

      # The PDF the process took at the start (P-06-17), once clean.
      def material
        authorize! :complete_own, @item
        material = @item.material
        raise ActiveRecord::RecordNotFound unless material&.clean?

        response.headers["Cache-Control"] = "private, no-store"
        send_data material.file.download, type: Documents::Upload::PDF, disposition: :inline, filename: material.file.filename.to_s
      end

      private

      # Only the person's own items of an open process; the others answer 404 (RN-03-006).
      def load_item
        @item = ProcessItem.accessible_by(current_ability, :complete_own).where(kind: KINDS).joins(:instance)
          .merge(ProcessInstance.open).includes(:instance).find(params[:id])
      end

      def resolve(done)
        if done
          redirect_to portal_root_path, notice: t("panel.portal.process_items.resolved")
        else
          redirect_to portal_item_path(@item), alert: @item.errors.full_messages.to_sentence
        end
      end
    end
  end
end
