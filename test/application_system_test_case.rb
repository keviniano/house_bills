require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  DOWNLOADS = Rails.root.join("tmp/system_test_downloads")

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ] do |options|
    options.add_preference("download.default_directory", DOWNLOADS.to_s)
    options.add_preference("download.prompt_for_download", false)
  end

  setup do
    FileUtils.rm_rf(DOWNLOADS)
    FileUtils.mkdir_p(DOWNLOADS)
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end

  # Signs in through the real button, with Google mocked by OmniAuth's test mode.
  def sign_in_with_google(email, name: email)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2", uid: "google-#{email}", info: { email: email, email_verified: true, name: name }
    )
    visit root_path
    click_on "Sign in with Google"
    assert_text "Signed in as #{name}"
  end

  # Waits for a browser download to finish and returns its path.
  def downloaded_file(pattern)
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop do
        file = Dir[DOWNLOADS.join(pattern)].first
        return file if file && !Dir[DOWNLOADS.join("*.crdownload")].any?
        sleep 0.1
      end
    end
  end
end
