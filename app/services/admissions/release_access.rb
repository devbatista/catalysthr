module Admissions
  # "Liberar acesso" (RN-07-020, D-252): the only way the admission's invitation goes out,
  # through the 72-hour invitation of spec 02. Released again, it sends a new one and the old
  # link stops working (RN-02-012). Who already has access needs no invitation, only the
  # notice with what's left to send (spec 15, admission.started). Returns the invitation, or
  # nil for who already has access. Raises ActiveRecord::RecordInvalid when a channel can't
  # be used, as the invitation does.
  module ReleaseAccess
    module_function

    def call(admission, channels:, by:)
      membership = admission.worker_profile.membership
      channels = Array(channels).map(&:to_s).compact_blank
      Invitations.refuse(membership, :invitation_channels, :blank) if membership.invited? && channels.empty?

      invitation = admission.with_lock do
        Invitations.refuse(membership, :base, :admission_closed) unless admission.open?

        issued = Invitations.issue(membership, channels: channels, invited_by: by) if membership.invited?
        admission.update!(invite_released_at: Time.current, invite_released_by: by) unless admission.released?
        issued
      end
      Invitations.deliver(invitation) if invitation
      notify(admission, membership) unless invitation
      AccessEvent.record!(kind: "admin", action: "admission_access_released", user: by, subject: admission)
      invitation
    end

    def notify(admission, membership)
      Notifications.notify!("admission.started", user: membership.user, membership: membership, company: admission.company,
        subject: admission, path: "/portal")
    end
    private_class_method :notify
  end
end
