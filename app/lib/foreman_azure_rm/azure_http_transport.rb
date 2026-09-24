require 'net/http'
require 'uri'

module ForemanAzureRm
  class AzureHttpTransport
    Response = Struct.new(:status, :headers, :body, keyword_init: true) do
      def success?
        (200..299).cover?(status)
      end

      def redirect?
        (300..399).cover?(status)
      end

      def accepted?
        status == 202
      end

      def created?
        status == 201
      end

      def no_content?
        status == 204
      end

      def header(name)
        headers[name] || headers[name.downcase] || headers[name.split('-').map(&:capitalize).join('-')]
      end
    end

    def initialize(proxy_uri: URI.parse(''), ssl_cert_store: nil)
      @proxy_uri = proxy_uri
      @ssl_cert_store = ssl_cert_store
    end

    def request(method:, url:, headers: {}, body: nil, open_timeout: 30, read_timeout: 300)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port, @proxy_uri.host, @proxy_uri.port, @proxy_uri.user, @proxy_uri.password)
      http.use_ssl = true
      http.cert_store = @ssl_cert_store if @ssl_cert_store
      http.open_timeout = open_timeout
      http.read_timeout = read_timeout

      klass = { get: Net::HTTP::Get, post: Net::HTTP::Post,
                put: Net::HTTP::Put, delete: Net::HTTP::Delete }.fetch(method)
      req = klass.new(uri)
      headers.each { |k, v| req[k] = v }
      req.body = body if body

      raw = http.request(req)
      to_response(raw)
    end

    private

    def to_response(raw)
      hdrs = {}
      raw.each_header { |k, v| hdrs[k] = v }
      Response.new(status: raw.code.to_i, headers: hdrs, body: raw.body)
    end
  end
end
