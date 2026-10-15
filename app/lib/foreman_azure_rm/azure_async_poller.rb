require 'json'

module ForemanAzureRm
  class AzureAsyncPoller
    MAX_POLL_SECONDS = 1800
    DEFAULT_POLL_INTERVAL = 5

    def initialize(&authenticated_get)
      @authenticated_get = authenticated_get
    end

    def poll(response, resource_url:, method: :put)
      async_url = response.header('Azure-AsyncOperation')
      location_url = response.header('Location')
      return nil unless async_url || location_url

      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + MAX_POLL_SECONDS
      last_response = response
      while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
        interval = last_response.header('Retry-After')&.to_i || DEFAULT_POLL_INTERVAL
        sleep interval

        poll_url = async_url || location_url
        last_response = @authenticated_get.call(poll_url)

        if async_url
          handle_async_operation_poll(last_response, resource_url, method)&.tap { |result| return result }
        else
          handle_location_poll(last_response)&.tap { |result| return result }
        end
      end
      raise AzureApiError.new("Async operation timed out after #{MAX_POLL_SECONDS} seconds", 504)
    end

    private

    def handle_async_operation_poll(poll_response, resource_url, method)
      raise AzureApiError.new("Async poll failed: HTTP #{poll_response.status} #{poll_response.body}", poll_response.status) unless poll_response.success?
      poll_json = begin
        JSON.parse(poll_response.body)
      rescue JSON::ParserError, TypeError
        raise AzureApiError.new("Async poll returned non-JSON body: #{poll_response.body&.truncate(200)}", poll_response.status)
      end
      status = poll_json['status']
      raise AzureApiError.new("Async poll response missing 'status' field: #{poll_response.body&.truncate(200)}", poll_response.status) unless status
      case status
      when 'Succeeded'
        return poll_response if method == :delete
        result = @authenticated_get.call(resource_url)
        raise AzureApiError.new("Final resource fetch failed after async Succeeded: HTTP #{result.status} #{result.body&.truncate(200)}", result.status) unless result.success?
        result
      when 'Failed', 'Canceled'
        raise AzureApiError.new("Async operation #{status}: #{poll_json.dig('error', 'message')}", 500)
      end
    end

    def handle_location_poll(poll_response)
      if poll_response.success? && !poll_response.accepted?
        poll_response
      elsif poll_response.accepted?
        nil
      else
        raise AzureApiError.new("Location poll failed: HTTP #{poll_response.status} #{poll_response.body}", poll_response.status)
      end
    end
  end
end
