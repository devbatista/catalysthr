module Panel
  # The HR's board of notices (spec 15, RN-15-070 to RN-15-073, D-656): the list, a new notice
  # now, later or as a draft, and the notice with how many of its audience opened it. The HR
  # analyst publishes to their units and sees those for everyone and those of their units;
  # each edits and withdraws their own, the HR administrator any. A published notice changes
  # only its validity and the pin. Behind the board's flag.
  class AnnouncementsController < BaseController
    before_action :require_current_company
    before_action :require_board
    before_action :load_announcement, only: %i[show edit update withdraw attachment]

    def index
      authorize! :read, Announcement
      @announcements = scope.includes(:author).order(Arel.sql("CASE announcements.status WHEN 'scheduled' THEN 0 WHEN 'draft' THEN 1 " \
        "WHEN 'published' THEN 2 ELSE 3 END"), updated_at: :desc).limit(100).to_a
    end

    def new
      authorize! :create, Announcement
      @form = form_for(Announcement.new)
    end

    def create
      authorize! :create, Announcement
      @form = form_for(Announcement.new, **form_params)
      if @form.save
        redirect_to announcement_path(@form.announcement), notice: saved_notice(@form.announcement)
      else
        render :new, status: :unprocessable_content
      end
    end

    def show
      authorize! :read, @announcement
      @audience = @announcement.audience_filter
      @reads = reads if can?(:read_reads, @announcement) && (@announcement.published? || @announcement.expired?)
    end

    def edit
      authorize! :update, @announcement
      return redirect_to(announcement_path(@announcement)) unless @announcement.withdrawable?

      @form = form_for(@announcement)
    end

    def update
      authorize! :update, @announcement
      return redirect_to(announcement_path(@announcement)) unless @announcement.withdrawable?

      @form = form_for(@announcement, **form_params)
      if @form.save
        redirect_to announcement_path(@announcement), notice: saved_notice(@announcement)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def withdraw
      authorize! :withdraw, @announcement
      @announcement.with_lock do
        @announcement.update!(status: "withdrawn", withdrawn_at: Time.current, withdrawn_by: current_user) if @announcement.withdrawable?
      end
      redirect_to announcement_path(@announcement), notice: t(".done")
    end

    # Only a clean file, through the platform (P-05-30, RN-01-014).
    def attachment
      authorize! :read, @announcement
      blob = @announcement.attachment_clean? ? @announcement.attachment.blob : nil
      raise ActiveRecord::RecordNotFound unless blob

      response.headers["Cache-Control"] = "private, no-store"
      send_data blob.download, type: blob.content_type, disposition: :inline, filename: blob.filename.to_s
    end

    private

    def require_board
      raise ActiveRecord::RecordNotFound unless FeatureFlags.enabled?(FeatureFlags::ANNOUNCEMENTS)
    end

    # Out of the viewer's reach answers 404 (RN-03-006).
    def scope
      Announcement.in_panel(current_ability.announcement_unit_ids)
    end

    def load_announcement
      @announcement = scope.find(params[:id])
    end

    def form_for(announcement, **attributes)
      Announcements::Form.new(announcement, by: current_user, unit_ids: current_ability.announcement_unit_ids, **attributes)
    end

    def form_params
      attributes = params.fetch(:announcement, {}).permit(:title, :body, :file, :remove_attachment, :mode, :publish_at, :expires_on, :pinned)
      audience = params.fetch(:audience, {}).permit(Announcements::Audience::LISTS.to_h { |key| [ key, [] ] })
      attributes.to_h.symbolize_keys.merge(audience: audience.to_h)
    end

    def saved_notice(announcement)
      key = announcement.published? ? "published" : announcement.status
      key = "waiting_scan" if announcement.scheduled? && announcement.publish_at <= Time.current
      t("panel.announcements.saved.#{key}")
    end

    # Who of the audience opened it, against the audience now (RN-15-072, D-656).
    def reads
      members = @announcement.audience_filter.members
      { opened: @announcement.reads.where(membership_id: members.select(:membership_id)).count, count: members.count }
    end
  end
end
