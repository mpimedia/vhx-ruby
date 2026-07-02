require 'spec_helper'

describe Vhx::Client do
  def application_only_credentials
    {api_key: "-12345"}
  end

  def application_user_credentials
    {
      client_id: '12345',
      client_secret: '12345',
      oauth_token: {
        access_token:  "123456",
        refresh_token: "12345",
        expires_at: 1430330123,
        expires_in: 7200
      }
    }
  end

  describe 'faraday configuration' do
    let(:vhx_client){ Vhx::Client.new(application_only_credentials)}

    it 'uses custom error response middleware' do
      expect(vhx_client.connection.builder.handlers).to include(Vhx::Middleware::ErrorResponse)
    end

    it 'does not utilize oauth2 middleware by default' do
      expect(vhx_client.connection.builder.handlers).to_not include(Vhx::Middleware::OAuth2)
    end

    it 'utilizes oauth2 middleware if auto_refresh option passed' do
      credentials = application_only_credentials.merge(auto_refresh: true)
      vhx_client = Vhx::Client.new(credentials)
      expect(vhx_client.connection.builder.handlers).to include(Vhx::Middleware::OAuth2)
    end

    it 'uses api host' do
      expect(vhx_client.connection.url_prefix.host).to eq 'api.vhx.tv'
    end

    describe 'middleware stack' do
      # Exact allowlist: any middleware addition — logging or otherwise —
      # must be reviewed here before it can ship (see mpimedia/harvest#688).
      let(:expected_stack) do
        [
          Faraday::Request::UrlEncoded,
          Faraday::Request::Json,
          Vhx::Middleware::ErrorResponse,
          Faraday::Response::Json
        ]
      end

      context 'with api_key credentials' do
        it 'matches the expected stack exactly' do
          expect(vhx_client.connection.builder.handlers).to eq(expected_stack)
        end
      end

      context 'with oauth credentials' do
        it 'matches the expected stack exactly' do
          vhx_client = Vhx::Client.new(application_user_credentials)
          expect(vhx_client.connection.builder.handlers).to eq(expected_stack)
        end
      end

      context 'with auto_refresh enabled' do
        it 'matches the expected stack exactly, with only OAuth2 added' do
          credentials = application_only_credentials.merge(auto_refresh: true)
          vhx_client = Vhx::Client.new(credentials)
          expect(vhx_client.connection.builder.handlers).to eq(
            expected_stack.insert(2, Vhx::Middleware::OAuth2)
          )
        end
      end

      it 'pins the net_http adapter (handlers does not cover the adapter slot)' do
        expect(vhx_client.connection.builder.adapter).to eq(Faraday::Adapter::NetHttp)
      end
    end
  end

  describe 'request logging' do
    def products_fixture
      File.read('spec/fixtures/sample_products_response.json')
    end

    # Faraday's logger middleware (if one regresses into the stack) binds
    # $stdout when the connection first builds its app stack, so the client
    # must be constructed and used entirely inside the capture block.
    # $stderr is captured too: a regressed sink could just as easily write
    # there, and container runtimes aggregate both streams into the same logs.
    def capture_output
      original_stdout = $stdout
      original_stderr = $stderr
      captured = StringIO.new
      $stdout = captured
      $stderr = captured
      yield
      captured.string
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
    end

    context 'with api_key (Basic) credentials' do
      it 'sends the Authorization header without writing it to stdout or stderr' do
        stub_request(:get, 'https://api.vhx.tv/products')
          .to_return(status: 200, body: products_fixture, headers: { 'Content-Type' => 'application/json' })

        output = capture_output do
          Vhx::Client.new(application_only_credentials).connection.get('/products')
        end

        expect(
          a_request(:get, 'https://api.vhx.tv/products')
            .with(headers: { 'Authorization' => "Basic #{['-12345:'].pack('m0')}" })
        ).to have_been_made.once
        expect(output).to_not include('Authorization')
        expect(output).to_not include(['-12345:'].pack('m0'))
        expect(output).to_not include('-12345')
      end
    end

    context 'with oauth (Bearer) credentials' do
      it 'sends the Authorization header without writing it to stdout or stderr' do
        stub_request(:get, 'https://api.vhx.tv/products')
          .to_return(status: 200, body: products_fixture, headers: { 'Content-Type' => 'application/json' })

        output = capture_output do
          Vhx::Client.new(application_user_credentials).connection.get('/products')
        end

        expect(
          a_request(:get, 'https://api.vhx.tv/products')
            .with(headers: { 'Authorization' => 'Bearer 123456' })
        ).to have_been_made.once
        expect(output).to_not include('Authorization')
        expect(output).to_not include('123456')
      end
    end

    context 'with an error response' do
      it 'raises the mapped error without writing the Authorization header to stdout or stderr' do
        stub_request(:get, 'https://api.vhx.tv/products')
          .to_return(status: 404, body: '{"message": "not found"}', headers: { 'Content-Type' => 'application/json' })

        output = capture_output do
          client = Vhx::Client.new(application_only_credentials)
          expect { client.connection.get('/products') }.to raise_error(Vhx::NotFoundError)
        end

        expect(
          a_request(:get, 'https://api.vhx.tv/products')
            .with(headers: { 'Authorization' => "Basic #{['-12345:'].pack('m0')}" })
        ).to have_been_made.once
        expect(output).to_not include('Authorization')
        expect(output).to_not include(['-12345:'].pack('m0'))
      end
    end
  end

  context 'application_only' do
    let(:vhx_client){ Vhx::Client.new(application_only_credentials)}

    describe 'connection' do
      it 'initializes faraday connection' do
        expect(vhx_client.connection).to be_an_instance_of(Faraday::Connection)
      end

      it 'authorization header presence' do
        expect(vhx_client.connection.headers['Authorization']).to_not be_nil
      end

      it 'basic auth presence' do
        expect(vhx_client.connection.headers['Authorization']).to match /Basic/
      end
    end
  end

  context 'application_user' do
    let!(:vhx_client){ Vhx::Client.new(application_user_credentials)}

    it 'oauth_token presence' do
      expect(vhx_client.oauth_token).to be_an_instance_of(OAuthToken)
    end

    describe 'connection' do
      it 'initializes faraday connection' do
        expect(vhx_client.connection).to be_an_instance_of(Faraday::Connection)
      end

      it 'authorization header presence' do
        expect(vhx_client.connection.headers['Authorization']).to_not be_nil
      end

      it 'Bearer auth presence' do
        expect(vhx_client.connection.headers['Authorization']).to match /Bearer/
      end
    end

    describe '#refresh_access_token!' do
      let(:oauth_token){ vhx_client.oauth_token }

      it 'oauth_token refreshed' do
        new_token_hash = {access_token: '123', refresh_token: '456', expires_in: '3600'}
        new_token_response = FakeResponse.new(new_token_hash)
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(new_token_response)
        original_access_token = oauth_token.access_token 
        vhx_client.refresh_access_token! 
        expect(vhx_client.oauth_token.refreshed).to eq(true)
      end

      it 'access_token changed' do
        new_token_hash = {access_token: '123', refresh_token: '456', expires_in: '3600'}
        new_token_response = FakeResponse.new(new_token_hash)
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(new_token_response)
        original_access_token = oauth_token.access_token 
        vhx_client.refresh_access_token! 
        expect(vhx_client.oauth_token.access_token).to_not eq(original_access_token)
      end
    end
  end
end
