# app/models/bling/credential.rb
module Bling
  class Credential < ApplicationRecord
    validates :expires_at, presence: true

    def self.current
      active.last
    end

    def expired?
      expires_at < Time.now + 5.minutes
    end
  end
end