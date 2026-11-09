module Panel
  module Portal
    # The board in the portal (spec 15, RN-15-072; spec 16, RN-16-011, D-656): the notices in
    # force whose audience reaches the person, the pinned first, and the history of the ones
    # that ended. Opening one counts as read (RN-15-072). Who is in a read-only period does not
    # have it (RN-16-051). Behind the board's flag.
    class AnnouncementsController < BaseController
      before_action :require_board
      before_action :require_profile
      before_action :load_announcement, only: %i[show attachment]

      def index
        authorize! :read_board, Announcement
        @live = Announcement.reaching(current_profile).live.board_order.to_a
        @past = Announcement.reaching(current_profile).past.order(expires_at: :desc).limit(50).to_a
        @read_ids = AnnouncementRead.where(membership: current_membership, announcement_id: (@live + @past).map(&:id)).pluck(:announcement_id).to_set
      end

      def show
        authorize! :read_board, Announcement
        AnnouncementRead.record!(@announcement, current_membership) if @announcement.live? && !impersonating?
      end

      # Only a clean file, through the platform (P-05-30, RN-01-014).
      def attachment
        authorize! :read_board, Announcement
        blob = @announcement.attachment_clean? ? @announcement.attachment.blob : nil
        raise ActiveRecord::RecordNotFound unless blob

        response.headers["Cache-Control"] = "private, no-store"
        send_data blob.download, type: blob.content_type, disposition: :inline, filename: blob.filename.to_s
      end

      private

      def require_board
        raise ActiveRecord::RecordNotFound unless FeatureFlags.enabled?(FeatureFlags::ANNOUNCEMENTS)
      end

      # A notice outside the person's audience, withdrawn or not up yet answers 404.
      def load_announcement
        @announcement = Announcement.reaching(current_profile).where(status: %w[published expired]).find(params[:id])
      end
    end
  end
end
