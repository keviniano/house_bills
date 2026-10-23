require "test_helper"

class SignInTest < ActionDispatch::IntegrationTest
  setup do
    create_household
    @ann.update!(email: "Ann@Example.com")
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end

  def sign_in_with_google(email:, uid: "google-#{email}", verified: true, name: "Google Name")
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2", uid: uid,
      info: { email: email, email_verified: verified, name: name }
    )
    post user_google_oauth2_omniauth_authorize_path
    follow_redirect!
  end

  test "the sign-in page offers Google and posts to it" do
    get new_user_session_path
    assert_response :success
    assert_select "form[action='#{user_google_oauth2_omniauth_authorize_path}'][method=post]"
  end

  test "signed-out visitors are sent to sign in" do
    get accounts_path
    assert_redirected_to new_user_session_path
  end

  test "an invited member signs in, gets a user and is linked to their membership" do
    sign_in_with_google(email: "ann@example.com", name: "Ann Google")

    user = User.find_by!(email: "ann@example.com")
    assert_equal [ "google_oauth2", "google-ann@example.com" ], [ user.provider, user.uid ]
    assert_equal user, @ann.reload.user
    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
  end

  test "someone who isn't a member anywhere is refused" do
    assert_no_difference -> { User.count } do
      sign_in_with_google(email: "stranger@example.com")
    end
    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_match "hasn't been invited", flash[:alert]
  end

  test "an unverified Google email is refused" do
    assert_no_difference -> { User.count } do
      sign_in_with_google(email: "ann@example.com", verified: false)
    end
    assert_redirected_to new_user_session_path
  end

  test "a user from the old app is matched by email, keeps their name and gets their Google uid" do
    legacy = User.create!(name: "Ann Legacy", email: "ann@example.com")

    assert_no_difference -> { User.count } do
      sign_in_with_google(email: "ANN@example.com", uid: "g-123")
    end
    assert_equal "g-123", legacy.reload.uid
    assert_equal "Ann Legacy", legacy.name
  end

  test "once linked, the Google uid wins even if the email changed" do
    user = User.create!(name: "Ann", email: "old@example.com", provider: "google_oauth2", uid: "g-123")

    sign_in_with_google(email: "new@example.com", uid: "g-123")
    assert_redirected_to root_path
    assert_equal "old@example.com", user.reload.email
  end

  test "signing out" do
    sign_in_with_google(email: "ann@example.com")
    delete destroy_user_session_path
    get accounts_path
    assert_redirected_to new_user_session_path
  end
end
