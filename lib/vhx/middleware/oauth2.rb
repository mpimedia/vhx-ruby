module Vhx
  module Middleware
    class OAuth2 < Faraday::Middleware
      def call(env)
        orig_env = env.dup

        begin
          @app.call(env)
        rescue InvalidTokenError
          @vhx_client.refresh_access_token!
          orig_env[:request_headers].merge!(@vhx_client.configured_headers)
          @app.call(orig_env)
        end
      end

      def initialize(app, vhx_client: nil, **options)
        super(app, **options)
        @vhx_client = vhx_client
      end
    end
  end
end