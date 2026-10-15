require 'json'
require 'uri'

module ForemanAzureRm
  class AzureRestClient
    AZURE_ENVIRONMENTS = {
      'azure' => {
        ad_login: 'https://login.microsoftonline.com',
        resource_manager: 'https://management.azure.com',
      },
      'azureusgovernment' => {
        ad_login: 'https://login.microsoftonline.us',
        resource_manager: 'https://management.usgovcloudapi.net',
      },
      'azurechina' => {
        ad_login: 'https://login.chinacloudapi.cn',
        resource_manager: 'https://management.chinacloudapi.cn',
      },
      'azuregermancloud' => {
        ad_login: 'https://login.microsoftonline.de',
        resource_manager: 'https://management.microsoftazure.de',
      },
    }.freeze

    attr_reader :subscription_id

    def initialize(tenant:, client_id:, client_secret:, subscription_id:, azure_environment: 'azure', proxy_url: nil, ssl_cert_store: nil)
      @tenant = tenant
      @client_id = client_id
      @client_secret = client_secret
      @subscription_id = subscription_id
      env = AZURE_ENVIRONMENTS[azure_environment.downcase]
      raise ArgumentError, "Unknown Azure environment: #{azure_environment}" unless env
      @ad_login_url = env[:ad_login]
      @base_url = env[:resource_manager]
      @token = nil
      @token_expires_at = 0
      @transport = AzureHttpTransport.new(
        proxy_uri: URI.parse(proxy_url || ENV['https_proxy'] || ENV['HTTPS_PROXY'] || ''),
        ssl_cert_store: ssl_cert_store
      )
      @translator = AzureShapeTranslator.new
      @poller = AzureAsyncPoller.new { |url| authenticated_get(url) }
    end

    def get(path, api_version:, params: {})
      request(:get, path, api_version: api_version, params: params)
    end

    def put(path, body, api_version:)
      request(:put, path, api_version: api_version, body: body)
    end

    def post(path, body = nil, api_version:)
      request(:post, path, api_version: api_version, body: body)
    end

    def delete(path, api_version:)
      request(:delete, path, api_version: api_version)
    end

    def get_paged(path, api_version:, params: {})
      results = []
      loop do
        response = get(path, api_version: api_version, params: params)
        items = response.respond_to?(:value) ? (response.value || []) : []
        results.concat(items)
        next_link = response.respond_to?(:next_link) ? response.next_link : nil
        break unless next_link
        path = URI.parse(next_link).request_uri
        params = {}
        api_version = nil
      end
      results
    end

    private

    def request(method, path, api_version: nil, params: {}, body: nil)
      ensure_token
      url = build_url(path, api_version, params)
      headers = auth_headers
      headers['Content-Type'] = 'application/json'
      headers['Accept'] = 'application/json'
      serialized = body ? @translator.serialize_request(body) : nil

      response = @transport.request(method: method, url: url, headers: headers, body: serialized)
      handle_response(response, method, url)
    end

    def handle_response(response, method, resource_url)
      if response.accepted? || response.created?
        if response.header('Azure-AsyncOperation') || response.header('Location')
          raw = @poller.poll(response, resource_url: resource_url, method: method)
          return nil if method == :delete
          return parse_body(raw) if raw
        end
        parse_body(response)
      elsif response.redirect?
        redirect_url = response.header('Location')
        raise AzureApiError.new("Unexpected redirect to #{redirect_url}", response.status) unless redirect_url
        request(:get, redirect_url)
      elsif response.success?
        if response.header('Azure-AsyncOperation')
          raw = @poller.poll(response, resource_url: resource_url, method: method)
          return nil if method == :delete
          return parse_body(raw) if raw
        end
        parse_body(response)
      else
        raise_api_error(response)
      end
    end

    def parse_body(response)
      return nil if response.body.blank?
      json = JSON.parse(response.body)
      @translator.normalize_response(json)
    end

    def raise_api_error(response)
      error = begin
        JSON.parse(response.body)
      rescue StandardError
        { 'error' => { 'message' => response.body } }
      end
      err = error.dig('error', 'message') || error.dig('error', 'code') || "HTTP #{response.status}"
      raise AzureApiError.new("Azure API error #{response.status}: #{err}", response.status)
    end

    def build_url(path, api_version, params)
      url = path.start_with?('http') ? path : "#{@base_url}#{path}"
      uri = URI.parse(url)
      query = URI.decode_www_form(uri.query || '')
      query << ['api-version', api_version] if api_version
      params.each { |k, v| query << [k.to_s, v.to_s] }
      uri.query = URI.encode_www_form(query)
      uri.to_s
    end

    def auth_headers
      { 'Authorization' => "Bearer #{@token}" }
    end

    def authenticated_get(url)
      ensure_token
      @transport.request(method: :get, url: url, headers: auth_headers, read_timeout: 30)
    end

    # --- Auth ---

    def ensure_token
      return if @token && Process.clock_gettime(Process::CLOCK_MONOTONIC) < @token_expires_at - 60

      url = "#{@ad_login_url}/#{@tenant}/oauth2/v2.0/token"
      response = @transport.request(
        method: :post,
        url: url,
        headers: { 'Content-Type' => 'application/x-www-form-urlencoded' },
        body: URI.encode_www_form(
          'grant_type' => 'client_credentials',
          'client_id' => @client_id,
          'client_secret' => @client_secret,
          'scope' => "#{@base_url}/.default"
        ),
        read_timeout: 30
      )
      raise AzureApiError.new("Token acquisition failed: #{response.body}", response.status) unless response.success?
      token_data = JSON.parse(response.body)
      @token = token_data['access_token']
      @token_expires_at = Process.clock_gettime(Process::CLOCK_MONOTONIC) + token_data['expires_in'].to_i
    end
  end

  class AzureApiError < StandardError
    attr_reader :status_code

    def initialize(message, status_code = nil)
      super(message)
      @status_code = status_code
    end
  end
end
