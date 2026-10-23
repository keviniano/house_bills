# Roles are reference data the app needs in every environment. Safe to re-run.
%w[User Power\ User Owner].each { |name| Role.find_or_create_by!(name: name) }

# Sample data for local development. Sign in with Google as the seeded email
# (set SEED_EMAIL to your own Google address) to be linked to this member.
if Rails.env.development? && !Account.exists?
  email = ENV.fetch("SEED_EMAIL", "test@example.com")
  user = User.find_or_create_by!(email: email) { |u| u.name = "Test User" }

  account = Account.create!(name: "Seed Account", owner_id: user.id)

  Shareholder.create!(
    name:       "Test User",
    email:      email,
    account_id: account.id,
    user_id:    user.id,
    role_id:    Role.owner.id,
    opened_on:  Date.current
  )

  BillType.create!(name: "Seed Bill Type", account_id: account.id)
  Payee.create!(name: "Seed Payee", account_id: account.id)
end
