class Shareholder < ActiveRecord::Base
  belongs_to :account
  belongs_to :user
  belongs_to :role
  
  validates_presence_of :name
  #validates_presence_of :email
  validates_presence_of :opened_on

  default_value_for :opened_on do
    Date.today
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
  end

  private

end
