# app/models/bling/base.rb
module Bling
  class Base
    def refresh_tokens(refresh_token)
      credentials = Base64.strict_encode64("#{ENV['BLING_CLIENT_ID']}:#{ENV['BLING_CLIENT_SECRET']}")

      response = RestClient.post(
        ENV['BLING_TOKEN_URL'],
        {
          grant_type: 'refresh_token',
          refresh_token: refresh_token
        }.to_query,
        {
          'Content-Type' => 'application/x-www-form-urlencoded',
          'Accept' => '1.0',
          'Authorization' => "Basic #{credentials}"
        }
      )

      JSON.parse(response.body)
    rescue RestClient::ExceptionWithResponse => e
      error_response = JSON.parse(e.response.body) rescue {}
      error_msg = error_response['error'] || e.message
      raise "Erro ao renovar token: #{error_msg}"
    end

    # Novo método para obter tokens com código de autorização
    def request_tokens_with_code(authorization_code)
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
      error_response = JSON.parse(e.response.body) rescue {}
      error_msg = error_response['error'] || e.message
      raise "Erro ao obter tokens: #{error_msg}"
    end

    protected

    def make_request(method, endpoint, data = nil)
      Bling::Auth.with_valid_token do |access_token|
        headers = {
          'Accept' => '1.0',
          'Authorization' => "Bearer #{access_token}",
          'Content-Type' => 'application/json'
        }

        RestClient::Request.execute(
          method: method,
          url: "#{ENV['BLING_API_URL']}#{endpoint}",
          payload: data&.to_json,
          headers: headers,
          timeout: 30
        )
      end
    rescue RestClient::ExceptionWithResponse => e
      error_response = begin
        JSON.parse(e.response.body)
      rescue
        { error: e.response.body }
      end

      raise "Erro na API Bling (#{e.response.code}): #{error_response['error'] || e.message}"
    end
  end
end