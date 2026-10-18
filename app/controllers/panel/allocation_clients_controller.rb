module Panel
  # The company's allocation clients (RN-04-090 to RN-04-096, D-570): the HR administrator
  # registers them, assigns and invites their managers (RN-02-064, D-605); the HR analyst
  # reads them. With the clients turned off, nothing here exists (RN-04-090).
  class AllocationClientsController < BaseController
    before_action :require_current_company
    before_action :require_allocation_clients
    before_action :load_client, except: %i[index new create]
    # Pages with an invitation link must not stay in any cache.
    before_action { response.headers["Cache-Control"] = "no-store" }

    helper_method :manager_options

    def index
      authorize! :read, AllocationClient
      @clients = AllocationClient.accessible_by(current_ability).includes(managers: :user).order(:status, :name)
    end

    def show
      authorize! :read, @client
      @allocated = WorkerProfile.in_allocation_clients(@client.id).includes(:user).to_a.sort_by(&:display_name)
    end

    def new
      authorize! :create, AllocationClient
      @client = AllocationClient.new
    end

    def create
      authorize! :create, AllocationClient
      @client = AllocationClient.new(client_params)
      @client.save ? redirect_to(allocation_client_path(@client), notice: t(".created")) : render(:new, status: :unprocessable_content)
    end

    def edit
      authorize! :update, @client
    end

    def update
      authorize! :update, @client
      if @client.update(client_params)
        AllocationClients.release_managers!(Current.company, by: current_user) if @client.inactive?
        redirect_to allocation_client_path(@client), notice: t(".updated")
      else
        render :edit, status: :unprocessable_content
      end
    end

    # The client's managers among the company's client managers (RN-04-094).
    def managers
      authorize! :manage_managers, @client
      AllocationClients.assign_managers!(@client, membership_ids: params[:membership_ids], by: current_user)
      redirect_to allocation_client_path(@client), notice: t(".assigned")
    end

    # Invites someone from the client as its manager, with MFA (RN-02-040, RN-02-064).
    def invite_manager
      authorize! :manage_managers, @client
      return redirect_to(allocation_client_path(@client), alert: t(".inactive")) if @client.inactive?

      form = params.fetch(:invitation, {}).permit(:name, :cpf, :email, :mobile_phone, channels: [])
      @invitation = ActiveRecord::Base.transaction do
        invitation = Invitations::Create.new(organization: Current.company, roles: %w[client_manager],
          channels: Array(form[:channels]).compact_blank, invited_by: current_user, name: form[:name], cpf: form[:cpf],
          email: form[:email].presence, mobile_phone: form[:mobile_phone].presence).issue
        @client.allocation_client_managers.create!(membership: invitation.membership)
        invitation
      end
      Invitations.deliver(@invitation)
      render "panel/memberships/invited"
    rescue ActiveRecord::RecordInvalid => error
      redirect_to allocation_client_path(@client), alert: error.record.errors.full_messages.to_sentence
    end

    private

    def require_allocation_clients
      raise ActiveRecord::RecordNotFound unless Current.company.uses_allocation_clients
    end

    def load_client
      @client = AllocationClient.accessible_by(current_ability, :read).find(params[:id])
    end

    def client_params
      params.expect(allocation_client: %i[name document_type document status])
    end

    def manager_options
      Membership.where(organization: Current.company).with_role("client_manager").where.not(status: "revoked")
        .includes(:user).sort_by { |membership| membership.user.name }
    end
  end
end
