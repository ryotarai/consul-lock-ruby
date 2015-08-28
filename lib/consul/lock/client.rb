module Consul
  module Lock
    class Client
      attr_reader :conn

      def initialize(url)
        @conn = Faraday.new(url: url) do |faraday|
          faraday.request  :url_encoded
          faraday.response :logger, Consul::Lock.logger
          faraday.adapter  Faraday.default_adapter
        end
      end

      def create_session(params = {})
        res = request(:put, "/v1/session/create", {}, params.to_json)
        JSON.parse(res.body)
      end

      def destroy_session(id)
        res = request(:put, "/v1/session/destroy/#{id}")
      end

      def get_kv(key, params = {})
        res = request(:get, "/v1/kv/#{key}", params)
        JSON.parse(res.body)
      end

      def put_kv(key, value, params = {})
        res = request(:put, "/v1/kv/#{key}", params, value)
        res.body == 'true' ? true : false
      end

      def delete_kv(key, params = {})
        request(:delete, "/v1/kv/#{key}", params)
      end

      private

      def request(method, path, url_query = {}, body = nil)
        path << "?" << URI.encode_www_form(url_query)
        res = @conn.public_send(method, path, body)
        unless 200 <= res.status && res.status < 300
          raise "invalid response (#{res.status})"
        end
        res
      end
    end
  end
end
