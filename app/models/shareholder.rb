class Shareholder < ActiveRecord::Base
  stampable
  belongs_to :account
  belongs_to :user
  belongs_to :role
  has_many   :bills
  has_many   :account_entries
  has_many   :balance_entries

  validates_presence_of :name
  validates_presence_of :opened_on
  validate :cannot_change_user_fields

  attr_protected :updated_through_user

  before_create :attach_user

  default_value_for :opened_on do
    Date.today
  end

  def balance
    balance_entries.sum(:amount)
  end

  def admin?
    role.name == 'Administrator' || role.name == 'Owner'
  end

  def owner?
    role.name == 'Owner'
  end
  
  def active?
    opened_on <= Date.today && (inactivated_on.nil? || inactivated_on > Date.today)
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
      where(:user_id => user.id)
    end

    def open_now
      where(["? BETWEEN shareholders.opened_on AND COALESCE(shareholders.closed_on,?)",Date.today,Date.today])    
    end

    def active_now
      where(["? BETWEEN shareholders.opened_on AND COALESCE(shareholders.inactivated_on,?)",Date.today,Date.today])    
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
    self.user = User.find_by_email(email) if email.present?
    true
  end

  def cannot_change_user_fields
    errors.add(:email, "Field cannot be changed except through associated user") if self.user.present? && self.email_changed? && !updated_through_user
    errors.add(:name, "Field cannot be changed except through associated user") if self.user.present? && self.name_changed? && !updated_through_user
  end

end
