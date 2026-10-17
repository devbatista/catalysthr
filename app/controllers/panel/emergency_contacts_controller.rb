module Panel
  # The person's emergency contacts (RN-04-041), edited by who edits the record (spec 03,
  # section 4.3).
  class EmergencyContactsController < EmployeeRecordsController
    before_action :load_contact, only: %i[edit update destroy]

    def new
      authorize! :update, @profile
      @contact = @profile.emergency_contacts.new
    end

    def create
      authorize! :update, @profile
      @contact = @profile.emergency_contacts.new(contact_params)
      @contact.save ? back_to_profile(notice: t(".created")) : render(:new, status: :unprocessable_content)
    end

    def edit
      authorize! :update, @profile
    end

    def update
      authorize! :update, @profile
      @contact.update(contact_params) ? back_to_profile(notice: t(".updated")) : render(:edit, status: :unprocessable_content)
    end

    def destroy
      authorize! :update, @profile
      @contact.destroy!
      back_to_profile(notice: t(".destroyed"))
    end

    private

    def load_contact
      @contact = @profile.emergency_contacts.find(params[:id])
    end

    def contact_params
      params.expect(emergency_contact: %i[name relationship phone])
    end
  end
end
