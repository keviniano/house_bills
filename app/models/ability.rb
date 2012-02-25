class Ability
  include CanCan::Ability

  def initialize(user)
    open_holdings = Shareholder.open_now.where(:user_id: user.id)
    active_holdings = open_holdings.delete_if {|holding| !holding.inactivated_on.nil? && holding.inactivated_on <= Date.today}
    admin_holdings = active_holdings.delete_if {|holding| !holding.admin? }
    non_admin_holdings = active_holdings.delete_if {|holding| holding.admin? }
    non_owner_holdings = active_holdings.delete_if {|holding| holding.owner? }

    # Any open user can read
    can    :read,   Account, :id: open_holdings.map{|r| r.account_id}
    # Admins can manage
    can    :manage, Account, :id: admin_holdings.map{|r| r.account_id}
    # But non-owners cannot delete
    cannot :delete, Account, :id: non_owner_holdings.map{|r| r.account_id}

    # Any open user can read
    can    :read,   BillType, :id: open_holdings.map{|r| r.account_id}
    # Admins can manage
    can    :manage, BillType, :id: admin_holdings.map{|r| r.account_id}

    # Any open user can read
    can    :read,   Payee, :id: open_holdings.map{|r| r.account_id}
    # Admins can manage
    can    :manage, Payee, :id: admin_holdings.map{|r| r.account_id}

    # Admins can manage the shareholder records of others 
    can    :manage, Shareholder, :account_id: admin_holdings.map{|r| r.account_id}
    # But they can't manage the shareholder records of owners if the user is not an owner themselves
    cannot :manage, Shareholder, :account_id: non_owner_holdings.map{|r| r.account_id}, :role_id: Role.owner.id
    # Any open user can read
    can    :read,   Shareholder, :account_id: open_holdings.map{|r| r.account_id}

    # Any open user can read
    can    :view,   AccountEntry, :account_id: open_holdings.map{|r| r.account_id}

    # Any open user can read
    can    :view,   BillAccountEntry, :account_id: open_holdings.map{|r| r.account_id}
    # Users can manage their own entries
    can    :manage, BillAccountEntry, :account_id: active_holdings.map{|r| r.account_id}, :created_by: user.id
    # Admins can manage any entry
    can    :manage, BillAccountEntry, :account_id: admin_holdings.map{|r| r.account_id}

    # Any open user can read
    can    :view,   ShareholderAccountEntry, :account_id: open_holdings.map{|r| r.account_id}
    # Users can manage their own entries
    can    :manage, ShareholderAccountEntry, :account_id: active_holdings.map{|r| r.account_id}, :created_by: user.id
    # Admins can manage any entry
    can    :manage, ShareholderAccountEntry, :account_id: admin_holdings.map{|r| r.account_id}

    # Any open user can read
    can    :view,   UnboundAccountEntry, :account_id: open_holdings.map{|r| r.account_id}
    # Users can manage their own entries
    can    :manage, UnboundAccountEntry, :account_id: active_holdings.map{|r| r.account_id}, :created_by: user.id
    # Admins can manage any entry
    can    :manage, UnboundAccountEntry, :account_id: admin_holdings.map{|r| r.account_id}




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
