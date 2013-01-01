class Ability
  include CanCan::Ability

  def initialize(user)
    open_holdings = Shareholder.open_now.where(:user_id => user.id)
    active_holdings = open_holdings.delete_if {|holding| !holding.inactivated_on.nil? && holding.inactivated_on <= Date.today}

    open_account_ids = open_holdings.map{|r| r.account_id}
    active_account_ids = active_holdings.map{|r| r.account_id }
    admin_account_ids = active_holdings.delete_if {|holding| !holding.admin? }.map {|r| r.account_id }
    non_owner_account_ids = active_holdings.delete_if {|holding| holding.owner? }.map {|r| r.account_id }

    # Any user can create a new account
    can    :create, Account
    # Any open user can read
    can    :read,   Account, :id => open_account_ids
    # Admins can manage
    can    :manage, Account, :id => admin_account_ids
    # But non-owners cannot delete
    cannot :delete, Account, :id => non_owner_account_ids

    # Any open user can read
    can    :read,   BillType, :account_id => open_account_ids
    # Admins can manage
    can    :manage, BillType, :account_id => admin_account_ids

    # Any open user can read
    can    :read,   Payee, :account_id => open_account_ids
    # Admins can manage
    can    :manage, Payee

    # Admins can manage the shareholder records of others 
    can    :manage, Shareholder, :account_id => admin_account_ids
    # But they can't manage the shareholder records of owners if the user is not an owner themselves
    cannot :manage, Shareholder, :account_id => non_owner_account_ids, :role_id => Role.owner.id
    # Any open user can read
    can    :read,   Shareholder, :account_id => open_account_ids

    # Any open user can read
    can    :read,   BalanceEntry, :account_id => open_account_ids

    # Any open user can read
    can    :read,   BalanceEvent, :account_id => open_account_ids

    # Any open user can read
    can    :read,   AccountEntry, :account_id => open_account_ids

    # Any open user can read
    can    :read,   ShareholderAccountEntry, :account_id => open_account_ids
    # Users can manage their own entries
    can    :manage, ShareholderAccountEntry, :account_id => active_account_ids, :creator_id => user.id
    # Admins can manage any entry
    can    :manage, ShareholderAccountEntry, :account_id => admin_account_ids

    # Any open user can read
    can    :read,   UnboundAccountEntry, :account_id => open_account_ids
    # Users can manage their own entries
    can    :manage, UnboundAccountEntry, :account_id => active_account_ids, :creator_id => user.id
    # Admins can manage any entry
    can    :manage, UnboundAccountEntry, :account_id => admin_account_ids
    
    # Any open user can mark which account entries have cleared
    can    :update_cleared, AccountEntry, :account_id => open_account_ids

    # Any open user can read
    can    :read,   Bill, :account_id => open_account_ids

    # Any open user can read
    can    :read,   AccountBill, :account_id => open_account_ids
    # Users can manage their own entries
    can    :manage, AccountBill, :account_id => active_account_ids, :creator_id => user.id
    # Admins can manage any entry
    can    :manage, AccountBill, :account_id => admin_account_ids

    # Any open user can read
    can    :read,   ShareholderBill, :account_id => open_account_ids
    # Users can manage their own entries
    can    :manage, ShareholderBill, :account_id => active_account_ids, :creator_id => user.id
    # Admins can manage any entry
    can    :manage, ShareholderBill, :account_id => admin_account_ids


    # Define abilities for the passed in user here. For example:
    #
    #   user ||= User.new # guest user (not logged in)
    #   if user.admin?
    #     can :manage, :all
    #   else
    #     can :read, :all
    #   end
    #
    # The first argument to `can` is the action you are giving the user permission to do.
    # If you pass :manage it will apply to every action. Other common actions here are
    # :read, :create, :update and :destroy.
    #
    # The second argument is the resource the user can perform the action on. If you pass
    # :all it will apply to every resource. Otherwise pass a Ruby class of the resource.
    #
    # The third argument is an optional hash of conditions to further filter the objects.
    # For example, here the user can only update published articles.
    #
    #   can :update, Article, :published => true
    #
    # See the wiki for details: https://github.com/ryanb/cancan/wiki/Defining-Abilities
  end
end
