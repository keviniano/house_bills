# Google sign-in only (plan D1). Devise handles the session, remember-me and sign-in
# tracking; there are no passwords, confirmations or emails.
Devise.setup do |config|
  require "devise/orm/active_record"

  config.case_insensitive_keys = [ :email ]
  config.strip_whitespace_keys = [ :email ]
  config.sign_out_via = :delete
  config.remember_for = 1.year

  config.omniauth :google_oauth2,
    ENV["GOOGLE_CLIENT_ID"]     || Rails.application.credentials.dig(:google, :client_id),
    ENV["GOOGLE_CLIENT_SECRET"] || Rails.application.credentials.dig(:google, :client_secret),
    scope: "openid,email,profile",
    prompt: "select_account"
end
