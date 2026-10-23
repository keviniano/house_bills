# Local sign-in without a Google OAuth client: `DEV_GOOGLE_EMAIL=you@example.com bin/dev`
# makes "Sign in with Google" sign in as that (verified) address. Development only.
if Rails.env.development? && ENV["DEV_GOOGLE_EMAIL"].present?
  email = ENV["DEV_GOOGLE_EMAIL"]

  OmniAuth.config.test_mode = true
  OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
    provider: "google_oauth2",
    uid: "dev-#{Digest::SHA256.hexdigest(email)[0, 16]}",
    info: { email: email, email_verified: true, name: email.split("@").first.titleize }
  )
end
