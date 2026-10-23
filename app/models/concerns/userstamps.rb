# Records who created and last changed a row in creator_id / updater_id, taken from
# Current.user. This replaces the userstamp gem, removed in 2015, which Ability still
# relies on. Rows saved without a signed-in user (imports, the console) are left alone.
module Userstamps
  extend ActiveSupport::Concern

  included do
    before_save :set_userstamps
  end

  private

  def set_userstamps
    user = Current.user or return

    if new_record?
      self.creator_id ||= user.id
      self.updater_id = user.id
    elsif has_changes_to_save?
      self.updater_id = user.id
    end
  end
end
