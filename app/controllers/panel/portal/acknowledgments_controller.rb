module Panel
  module Portal
    # "Li e estou ciente" (spec 08, RN-08-051, RN-08-052, D-279): the employee confirms the
    # receipt of a document, with an optional comment; the date, the time, the IP, the
    # browser and the file's hash stay recorded (CA-08-007). It is not agreement nor a
    # signature (D-147).
    class AcknowledgmentsController < BaseController
      before_action :require_profile

      def confirm
        acknowledgment = Acknowledgment.accessible_by(current_ability, :acknowledge).find(params[:id])
        authorize! :acknowledge, acknowledgment
        done = Documents::Acknowledge.new(acknowledgment).confirm(by: current_user, ip: request.remote_ip,
          user_agent: request.user_agent, comment: params[:comment])
        if done
          redirect_to portal_document_path(acknowledgment.document_id), notice: t(".confirmed")
        else
          redirect_to portal_document_path(acknowledgment.document_id), alert: acknowledgment.errors.full_messages.to_sentence
        end
      end
    end
  end
end
