# app/models/bling/oauth.rb
module Bling
  class Oauth
    class << self
      def authorization_url(state)
        "#{ENV['BLING_AUTH_URL']}?" + {
          response_type: 'code',
          client_id: ENV['BLING_CLIENT_ID'],
          state: state
        }.to_query
      end

      def fetch_tokens(authorization_code)
        credentials = Base64.strict_encode64("#{ENV['BLING_CLIENT_ID']}:#{ENV['BLING_CLIENT_SECRET']}")

        response = RestClient.post(
          ENV['BLING_TOKEN_URL'],
          {
            grant_type: 'authorization_code',
            code: authorization_code
          }.to_query,
          {
            'Content-Type' => 'application/x-www-form-urlencoded',
            'Accept' => '1.0',
            'Authorization' => "Basic #{credentials}"
          }
        )

        JSON.parse(response.body)
      rescue RestClient::ExceptionWithResponse => e
        raise "Falha ao obter tokens: #{e.response.body}"
      end
    end
  end
end