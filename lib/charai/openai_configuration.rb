module Charai
  class OpenaiConfiguration
    def initialize(model:, api_key:)
      @endpoint_url = 'https://api.openai.com/v1/chat/completions'
      @model = model
      @api_key = api_key
    end

    attr_reader :endpoint_url

    def add_auth_header(headers)
      headers['Authorization'] = "Bearer #{@api_key}"
      headers
    end

    def decorate_body(payload)
      payload[:model] = @model
      payload
    end
  end

  class AzureOpenaiConfiguration
    def initialize(endpoint_url:, api_key:)
      @endpoint_url = endpoint_url
      @api_key = api_key
    end

    attr_reader :endpoint_url

    def add_auth_header(headers)
      headers['api-key'] = @api_key
      headers
    end

    def decorate_body(payload)
      payload
    end
  end

  class OllamaConfiguration
    def initialize(endpoint_url:, model:)
      @endpoint_url = endpoint_url
      @model = model
    end

    attr_reader :endpoint_url

    def add_auth_header(headers)
      # auth header is not required.
      headers
    end

    def decorate_body(payload)
      payload[:model] = @model
      payload
    end
  end
end
