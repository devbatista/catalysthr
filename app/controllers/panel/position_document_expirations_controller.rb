module Panel
  # The months of a periodicity type for a position, such as the periodic ASO every 6
  # months in a risky position (D-272, RN-08-030), by the HR administrator.
  class PositionDocumentExpirationsController < BaseController
    before_action :require_current_company
    before_action :load_type

    def create
      authorize! :configure_expiration, @type
      attributes = params.expect(position_expiration: %i[position_id expiration_months])
      expiration = @type.position_expirations.find_or_initialize_by(position: Position.find(attributes[:position_id]))
      expiration.expiration_months = attributes[:expiration_months]
      if expiration.save
        redirect_to document_types_path(anchor: "type-#{@type.id}"), notice: t(".saved", position: expiration.position.name)
      else
        redirect_to document_types_path(anchor: "type-#{@type.id}"), alert: expiration.errors.full_messages.to_sentence
      end
    end

    def destroy
      authorize! :configure_expiration, @type
      expiration = @type.position_expirations.find(params[:id])
      expiration.destroy!
      redirect_to document_types_path(anchor: "type-#{@type.id}"), notice: t(".destroyed", position: expiration.position.name)
    end

    private

    def load_type
      @type = DocumentType.accessible_by(current_ability, :read).find(params[:document_type_id])
    end
  end
end
