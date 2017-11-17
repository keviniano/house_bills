class Shareholder < ApplicationRecord
  belongs_to :account
  belongs_to :user, optional: true
  belongs_to :role
  has_many   :bills
  has_many   :account_entries
  has_many   :balance_entries

  has_paper_trail

  validate  :opened_on_string_format_must_be_valid
  validate  :inactivated_on_string_format_must_be_valid
  validate  :closed_on_string_format_must_be_valid
  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :role_id, presence: true
  validates :opened_on_string, presence: true

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

  def opened_on_string=(value)
    @opened_on_string = value
    self.opened_on = (value.blank? ? nil : DateTime.strptime(value,'%m-%d-%Y'))
  rescue ArgumentError
    @opened_on_string_invalid = true
  end

  def opened_on_string
    @opened_on_string || opened_on.try(:strftime,'%m-%d-%Y')
  end

  def inactivated_on_string=(value)
    @inactivated_on_string = value
    self.inactivated_on = (value.blank? ? nil : DateTime.strptime(value,'%m-%d-%Y'))
  rescue ArgumentError
    @inactivated_on_string_invalid = true
  end

  def inactivated_on_string
    @inactivated_on_string || inactivated_on.try(:strftime,'%m-%d-%Y')
  end

  def closed_on_string=(value)
    @closed_on_string = value
    self.closed_on = (value.blank? ? nil : DateTime.strptime(value,'%m-%d-%Y'))
  rescue ArgumentError
    @closed_on_string_invalid = true
  end

  def closed_on_string
    @closed_on_string || closed_on.try(:strftime,'%m-%d-%Y')
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
      self.user = User.find_by(email: email) if email.present?
      true
    end

    def opened_on_string_format_must_be_valid
      errors.add(:opened_on_string, "is invalid") if @opened_on_string_invalid
    end

    def inactivated_on_string_format_must_be_valid
      errors.add(:inactivated_on_string, "is invalid") if @inactivated_on_string_invalid
    end

    def closed_on_string_format_must_be_valid
      errors.add(:closed_on_string, "is invalid") if @closed_on_string_invalid
    end
end
