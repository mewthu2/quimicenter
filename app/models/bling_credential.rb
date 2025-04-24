# app/models/bling_credential.rb
class BlingCredential < ApplicationRecord
  validates :access_token, presence: true
  validates :refresh_token, presence: true
  validates :expires_at, presence: true
  validates :token_type, presence: true

  scope :active, -> { where(active: true) }

  def self.current
    active.last || raise('Nenhuma credencial ativa encontrada')
  end

  def expired?
    expires_at < Time.current + 5.minutes
  end

  def update_from_response(response)
    update!(
      access_token: response['access_token'],
      refresh_token: response['refresh_token'] || self.refresh_token,
      expires_at: Time.current + response['expires_in'].seconds,
      token_type: response['token_type'],
      active: true
    )
  end

  def self.create_or_update_credentials(attributes)
    active.update_all(active: false)
    create!(attributes.merge(active: true))
  end
end