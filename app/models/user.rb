class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :name, :email, :password, :password_confirmation, :remember_me

  has_one :shareholder

  validates_presence_of :name

  after_create :attach_shareholders


  private

  def attach_shareholders
    shareholders = Shareholder.find_all_by_email(email)
    shareholders.each do |m|
      m.user = self
      m.name = name
      m.save!
    end
  end
end
