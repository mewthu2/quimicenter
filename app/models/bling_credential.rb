# app/models/bling_credential.rb
class BlingCredential < ApplicationRecord
  # Validações básicas
  validates :access_token, presence: true
  validates :refresh_token, presence: true
  validates :expires_at, presence: true
  validates :token_type, presence: true

  # Scope para credencial ativa
  scope :active, -> { where(active: true) }

  # Método principal para obter a credencial atual
  def self.current
    active.last || raise("Nenhuma credencial ativa encontrada")
  end

  # Verifica se o token expirou (com margem de segurança de 5 minutos)
  def expired?
    expires_at < Time.current + 5.minutes
  end

  # Atualiza os tokens com uma resposta da API
  def update_from_response(response)
    update!(
      access_token: response['access_token'],
      refresh_token: response['refresh_token'] || self.refresh_token, # Mantém o anterior se não vier novo
      expires_at: Time.current + response['expires_in'].seconds,
      token_type: response['token_type'],
      active: true
    )
  end

  # Cria ou substitui as credenciais ativas
  def self.create_or_update_credentials(attributes)
    active.update_all(active: false) # Desativa todas as outras
    create!(attributes.merge(active: true))
  end
end