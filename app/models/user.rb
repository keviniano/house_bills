class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :confirmable,
         :recoverable, :rememberable, :trackable, :validatable

  model_stamper

  has_many :shareholders
  has_many :accounts, :through => :shareholders

  validates_presence_of :name
  validates_presence_of :email

  after_create :attach_shareholders
  after_save   :update_shareholders

  def shareholder_for_account(account)
    Shareholder.where(:user_id => self.id, :account_id => account.id).first
  end

  private

  def attach_shareholders
    shareholders = Shareholder.find_all_by_email(email)
    shareholders.each do |m|
      m.user = self
      m.name = name
      m.updated_through_user = true
      m.save!
    end
  end

  def update_shareholders
    self.shareholders.each do |m|
      m.name = name
      m.email = email
      m.updated_through_user = true
      m.save!
    end
  end
end
