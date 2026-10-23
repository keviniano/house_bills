class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    user = User.from_google(request.env["omniauth.auth"])

    if user
      user.remember_me = true
      set_flash_message(:notice, :success, kind: "Google")
      sign_in_and_redirect user, event: :authentication
    else
      redirect_to new_user_session_path,
        alert: "That Google account hasn't been invited. Ask an account admin to add you as a shareholder with that email address."
    end
  end

  def failure
    redirect_to new_user_session_path, alert: "Google sign-in didn't complete. Please try again."
  end
end
