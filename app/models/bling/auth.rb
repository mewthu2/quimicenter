# app/models/bling/auth.rb
module Bling
  class Auth
    class << self
      def check_token_status
        cred = BlingCredential.current
        status = {
          access_token: "#{cred.access_token[0..6]}...",
          refresh_token: "#{cred.refresh_token[0..6]}...",
          expires_at: cred.expires_at,
          hours_remaining: ((cred.expires_at - Time.current) / 3600).round(2),
          status: cred.expired? ? 'Expirado' : 'Válido'
        }

        puts 'Status do Token:'
        status.each { |k, v| puts "#{k.to_s.rjust(15)}: #{v}" }
        status
      end

      # Método público para renovação manual
      def refresh_credentials!
        credential = BlingCredential.current
        new_tokens = refresh_tokens(credential)
        puts '✅ Tokens renovados com sucesso!'
        puts "🔄 Novo access_token válido até: #{new_tokens.expires_at}"
        new_tokens
      rescue StandardError => e
        puts "❌ Falha na renovação: #{e.message}"
        raise
      end

      # Método para obter novos tokens com código de autorização
      def request_new_tokens(authorization_code)
        response = Base.new.request_tokens_with_code(authorization_code)
        credential = create_or_update_credentials(response)

        puts '✅ Novos tokens obtidos com sucesso!'
        puts "🆕 Access Token válido até: #{credential.expires_at}"
        credential
      rescue StandardError => e
        puts "❌ Falha ao obter novos tokens: #{e.message}"
        raise
      end

      # Método principal para uso interno
      def with_valid_token
        credential = BlingCredential.current

        if credential.expired?
          credential = refresh_tokens(credential)
          credential.reload
        end

        yield credential.access_token
      end

      private

      def refresh_tokens(credential)
        response = Base.new.refresh_tokens(credential.refresh_token)
        update_credentials(credential, response)
      rescue StandardError => e
        credential.update!(active: false)
        raise "Falha ao renovar token: #{e.message}"
      end

      def create_or_update_credentials(tokens)
        BlingCredential.update_all(active: false) if BlingCredential.any?

        BlingCredential.create!(
          access_token: tokens['access_token'],
          refresh_token: tokens['refresh_token'],
          expires_at: Time.current + tokens['expires_in'].seconds,
          token_type: tokens['token_type'],
          active: true
        )
      end

      def update_credentials(credential, tokens)
        credential.update!(
          access_token: tokens['access_token'],
          refresh_token: tokens['refresh_token'] || credential.refresh_token,
          expires_at: Time.current + tokens['expires_in'].seconds
        )
        credential
      end
    end
  end
end