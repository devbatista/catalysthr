# The first time a person of the audience opened a notice of the board (RN-15-072): the HR
# sees how many opened it. One per membership.
class AnnouncementRead < ApplicationRecord
  acts_as_tenant :company

  belongs_to :announcement
  belongs_to :membership

  validates :read_at, presence: true

  # Opening again keeps the first time; two tabs at once make one line.
  def self.record!(announcement, membership)
    insert_all([ { company_id: announcement.company_id, announcement_id: announcement.id, membership_id: membership.id, read_at: Time.current } ],
      unique_by: %i[announcement_id membership_id])
  end
end
