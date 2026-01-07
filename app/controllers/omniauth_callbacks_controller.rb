# frozen_string_literal: true

class OmniauthCallbacksController < Devise::OmniauthCallbacksController
  respond_to :html

  def google_oauth2
    auth = request.env["omniauth.auth"]
    email = auth.dig("info", "email").to_s.downcase

    verified =
      auth.dig("info", "verified") ||
      auth.dig("info", "email_verified") ||
      auth.dig("extra", "raw_info", "email_verified")

    if email.blank? || !verified
      redirect_to new_user_session_path, alert: "Google sign-in failed."
      return
    end

    allowed_domain = ENV["GOOGLE_ALLOWED_DOMAIN"].presence
    if allowed_domain.present? && !email.end_with?("@#{allowed_domain}")
      redirect_to new_user_session_path, alert: "Google sign-in failed."
      return
    end

    user = User.from_omniauth(auth)

    if user&.persisted?
      sign_in_and_redirect user, event: :authentication
    else
      redirect_to new_user_session_path, alert: "Google sign-in failed."
    end
  end

  def failure
    redirect_to new_user_session_path, alert: "Google sign-in failed."
  end
end
