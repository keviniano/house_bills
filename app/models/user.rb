class User < ApplicationRecord
  devise :omniauthable, :rememberable, :trackable, omniauth_providers: [ :google_oauth2 ]

  has_paper_trail

  has_many :shareholders
  has_many :accounts, :through => :shareholders

  validates_presence_of :name
  validates_presence_of :email

  after_create :attach_shareholders
  after_save   :update_shareholders

  # The user for a Google sign-in, or nil if they haven't been invited. Matches by Google
  # account, then by verified email (users from the 2011-2017 app have no uid yet), and
  # otherwise creates a user only when a member somewhere has that email address.
  def self.from_google(auth)
    email = auth.info.email.to_s.strip.downcase
    return nil if email.blank? || !auth.info.email_verified

    user = find_by(provider: auth.provider, uid: auth.uid) ||
           where("lower(email) = ?", email).first
    if user
      user.update!(provider: auth.provider, uid: auth.uid) if user.uid.blank?
      return user
    end

    return nil unless Shareholder.where("lower(email) = ?", email).exists?

    create!(provider: auth.provider, uid: auth.uid, email: email,
            name: auth.info.name.presence || email)
  end

  def shareholder_for_account(account)
    Shareholder.where(:user_id => self.id, :account_id => account.id).first
  end

  private

  def attach_shareholders
    shareholders = Shareholder.where("lower(email) = ?", email.downcase)
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
