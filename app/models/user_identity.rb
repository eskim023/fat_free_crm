# frozen_string_literal: true

class UserIdentity < ActiveRecord::Base
  belongs_to :user

  validates :provider, :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }
end
