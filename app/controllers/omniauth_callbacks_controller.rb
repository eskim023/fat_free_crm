# frozen_string_literal: true

class OmniauthCallbacksController < Devise::OmniauthCallbacksController
  respond_to :html

  def google_oauth2
    auth = request.env["omniauth.auth"] || {}
    email = auth.dig("info", "email").to_s.downcase

    raw_verified =
      auth.dig("info", "verified") ||
      auth.dig("info", "email_verified") ||
      auth.dig("extra", "raw_info", "email_verified")

    # Some providers omit this; treat nil as "not provided" rather than unverified.
    verified = raw_verified.nil? || raw_verified == true || raw_verified.to_s == "true"

    if email.blank? || !verified
      Rails.logger.info("Google OAuth rejected: email=#{email.inspect} verified=#{raw_verified.inspect}")
      redirect_to new_user_session_path, alert: t(:msg_invalig_login)
      return
    end

    allowed_domain = ENV["GOOGLE_ALLOWED_DOMAIN"].presence
    if allowed_domain.present? && !email.end_with?("@#{allowed_domain}")
      Rails.logger.info("Google OAuth rejected: email domain not allowed email=#{email.inspect} allowed_domain=#{allowed_domain.inspect}")
      redirect_to new_user_session_path, alert: t(:msg_invalig_login)
      return
    end

    user = User.from_omniauth(auth)

    if user&.persisted?
      sign_in_and_redirect user, event: :authentication
    else
      Rails.logger.info("Google OAuth failed: user not persisted email=#{email.inspect}")
      redirect_to new_user_session_path, alert: t(:msg_invalig_login)
    end
  end

  def failure
    redirect_to new_user_session_path, alert: t(:msg_invalig_login)
  end
end
