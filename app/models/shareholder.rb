class Shareholder < ApplicationRecord
  include Userstamps

  belongs_to :account, optional: true
  belongs_to :user, optional: true
  belongs_to :role, optional: true
  # Members with history can't be deleted; close them with closed_on instead.
  has_many   :bills, dependent: :restrict_with_error
  has_many   :account_entries, dependent: :restrict_with_error
  has_many   :balance_entries, dependent: :restrict_with_error

  has_paper_trail

  attribute :opened_on, default: -> { Date.current }

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :role_id, presence: true
  validates :opened_on, presence: true

  before_create :attach_user

  def balance
    balance_entries.sum_money
  end

  def admin?
    role.name == 'Administrator' || role.name == 'Owner'
  end

  def owner?
    role.name == 'Owner'
  end

  def active?
    opened_on <= Date.current && (inactivated_on.nil? || inactivated_on > Date.current)
  end

  def status
    active? ? 'Active' : 'Inactive'
  end

  def updated_through_user=(val)
    @updated_through_user = !!val
  end

  def updated_through_user
    @updated_through_user || false
  end

  class << self
    def by_user(user)
      find_by(user_id: user.id)
    end

    def open_now
      open_as_of(Date.current)
    end

    def active_now
      active_as_of(Date.current)
    end

    def open_as_of(date)
      where(["? BETWEEN shareholders.opened_on AND COALESCE(shareholders.closed_on,?)",date,date])
    end

    def active_as_of(date)
      where(["? BETWEEN shareholders.opened_on AND COALESCE(shareholders.inactivated_on,?)",date,date])
    end

    def for_account(account)
      where(:account_id => account.id)
    end
  end

  private

    def attach_user
      self.user = User.find_by(email: email) if email.present?
    end
end
