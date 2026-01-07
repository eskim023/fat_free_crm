# frozen_string_literal: true

# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
# == Schema Information
#
# Table name: users
#
#  id                  :integer         not null, primary key
#  username            :string(32)      default(""), not null
#  email               :string(254)     default(""), not null
#  first_name          :string(32)
#  last_name           :string(32)
#  title               :string(64)
#  company             :string(64)
#  alt_email           :string(64)
#  phone               :string(32)
#  mobile              :string(32)
#  aim                 :string(32)
#  yahoo               :string(32)
#  google              :string(32)
#  encrypted_password  :string(255)     default(""), not null
#  password_salt       :string(255)     default(""), not null
#  last_sign_in_at     :datetime
#  current_sign_in_at  :datetime
#  last_sign_in_ip     :string(255)
#  current_sign_in_ip  :string(255)
#  sign_in_count       :integer         default(0), not null
#  deleted_at          :datetime
#  created_at          :datetime
#  updated_at          :datetime
#  admin               :boolean         default(FALSE), not null
#  suspended_at        :datetime
#  unconfirmed_email   :string(254)     default(""), not null
#  reset_password_token    :string(255)
#  reset_password_sent_at  :datetime
#  remember_token          :string(255)
#  remember_created_at     :datetime
#  authentication_token    :string(255)
#  confirmation_token      :string(255)
#  confirmed_at            :datetime
#  confirmation_sent_at    :datetime
#

class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :confirmable,
         :encryptable, :recoverable, :rememberable, :trackable,
         :omniauthable, omniauth_providers: %i[google_oauth2]

  has_one :avatar, as: :entity, dependent: :destroy  # Personal avatar.
  has_many :avatars                                  # As owner who uploaded it, ex. Contact avatar.
  has_many :comments, as: :commentable               # As owner who created a comment.
  has_many :user_identities, dependent: :destroy
  has_many :accounts
  has_many :campaigns
  has_many :leads
  has_many :contacts
  has_many :opportunities
  has_many :assigned_opportunities, class_name: 'Opportunity', foreign_key: 'assigned_to'
  has_many :permissions, dependent: :destroy
  has_many :preferences, class_name: 'Preference', dependent: :destroy
  has_many :lists
  has_and_belongs_to_many :groups

  has_paper_trail versions: { class_name: 'Version' }, ignore: [:last_sign_in_at]

  scope :by_id, -> { order(id: :desc) }
  # TODO: /home/clockwerx/.rbenv/versions/2.5.3/lib/ruby/gems/2.5.0/gems/activerecord-5.2.3/lib/active_record/scoping/named.rb:175:in `scope': You tried to define a scope named "without" on the model "User", but ActiveRecord::Relation already defined an instance method with the same name. (ArgumentError)
  scope :without_user, ->(user) { where('id != ?', user.id).by_name }
  scope :by_name, -> { order(:first_name, :last_name, :email) }

  scope :text_search, lambda { |query|
    query = query.gsub(/[^\w\s\-.'\p{L}]/u, '').strip
    where('upper(username) LIKE upper(:s) OR upper(email) LIKE upper(:s) OR upper(first_name) LIKE upper(:s) OR upper(last_name) LIKE upper(:s)', s: "%#{query}%")
  }

  scope :my, ->(current_user) { accessible_by(current_user.ability) }

  scope :have_assigned_opportunities, lambda {
    joins("INNER JOIN opportunities ON users.id = opportunities.assigned_to")
      .where("opportunities.stage <> 'lost' AND opportunities.stage <> 'won'")
      .select('DISTINCT(users.id), users.*')
  }

  validates :email,
            presence: { message: :missing_email },
            length: { minimum: 3, maximum: 254 },
            uniqueness: { message: :email_in_use, case_sensitive: false },
            format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i, on: :create }
  validates :username,
            uniqueness: { message: :username_taken, case_sensitive: false },
            presence: { message: :missing_username },
            format: { with: /\A[a-z0-9_-]+\z/i }
  validates :password,
            presence: { if: :password_required? },
            confirmation: true

  #----------------------------------------------------------------------------
  def name
    first_name.blank? ? username : first_name
  end

  #----------------------------------------------------------------------------
  def full_name
    first_name.blank? && last_name.blank? ? email : "#{first_name} #{last_name}".strip
  end

  #----------------------------------------------------------------------------
  def suspended?
    suspended_at != nil
  end

  #----------------------------------------------------------------------------
  def active_for_authentication?
    super && confirmed? && !suspended?
  end

  def inactive_message
    if !confirmed?
      super
    elsif suspended?
      I18n.t(:msg_invalig_login)
    else
      super
    end
  end

  # Send emails to active users only
  #----------------------------------------------------------------------------
  def emailable?
    confirmed? && !suspended? && email.present?
  end

  #----------------------------------------------------------------------------
  def preference
    @preference ||= preferences.build
  end
  alias pref preference

  # Override global I18n.locale if the user has individual local preference.
  #----------------------------------------------------------------------------
  def set_individual_locale
    I18n.locale = preference[:locale] if preference[:locale]
  end

  # Generate the value of single access token if it hasn't been set already.
  #----------------------------------------------------------------------------
  def to_json(_options = nil)
    [name].to_json
  end

  def to_xml(_options = nil)
    [name].to_xml
  end

  def password_required?
    !persisted? || !password.nil? || !password_confirmation.nil?
  end

  # Returns permissions ability object.
  #----------------------------------------------------------------------------
  def ability
    @ability ||= Ability.new(self)
  end

  # Returns true if this user is allowed to be destroyed.
  #----------------------------------------------------------------------------
  def destroyable?(current_user)
    current_user != self && !has_related_assets?
  end

  # Prevent deleting a user unless she has no artifacts left.
  #----------------------------------------------------------------------------
  def has_related_assets?
    sum = %w[Account Campaign Lead Contact Opportunity Comment Task].detect do |asset|
      klass = asset.constantize

      asset != "Comment" && klass.assigned_to(self).exists? || klass.created_by(self).exists?
    end
    !sum.nil?
  end

  # Define class methods
  #----------------------------------------------------------------------------
  class << self
    def can_signup?
      Setting.user_signup == :allowed
    end

    # Overrides Devise sign-in to use either username or email (case-insensitive)
    #----------------------------------------------------------------------------
    def find_for_database_authentication(warden_conditions)
      conditions = warden_conditions.dup
      if login = conditions.delete(:email)
        where(conditions.to_h).where(["lower(username) = :value OR lower(email) = :value", { value: login.downcase }]).first
      end
    end

    def from_omniauth(auth)
      identity = UserIdentity.find_or_initialize_by(provider: auth.provider, uid: auth.uid)
      identity.email = auth.dig("info", "email")
      identity.token = auth.dig("credentials", "token")
      identity.refresh_token ||= auth.dig("credentials", "refresh_token")
      identity.expires_at = Time.at(auth.dig("credentials", "expires_at").to_i) if auth.dig("credentials", "expires_at").present?

      return identity.user if identity.user

      email = identity.email.to_s.downcase
      user = User.find_by(email: email)

      unless user
        return nil unless can_signup?

        base = email.split("@").first.to_s.downcase
        base = base.gsub(/[^a-z0-9_-]+/, "_").gsub(/\A_+|_+\z/, "")
        base = "user" if base.blank?

        username = base
        i = 1
        while User.exists?(username: username)
          i += 1
          username = "#{base}_#{i}"
        end

        user = User.new(
          email: email,
          username: username,
          first_name: auth.dig("info", "first_name"),
          last_name: auth.dig("info", "last_name"),
          confirmed_at: Time.current,
          password: Devise.friendly_token.first(32)
        )
        user.save
      end

      return nil unless user&.persisted?

      identity.user = user
      identity.save
      user
    end
  end

  ActiveSupport.run_load_hooks(:fat_free_crm_user, self)
end
