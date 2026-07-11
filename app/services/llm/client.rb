module LLM
  # Low-level provider plumbing over ruby_llm: one call in, usage row out.
  # Model-based (not role-based) — LLM::Gateway resolves roles to models and is
  # the hob-shaped surface callers should use. (Ported from kat.)
  class Client
    attr_reader :model

    def initialize(model:)
      @model = model
      raise LLM::Error, "LLM not configured — missing API key" unless LLM.enabled?
    end

    # When a structured-output call comes back as prose with no JSON object, the
    # model has almost always declined the task (it argues instead of answering)
    # rather than produced malformed JSON. Lets callers tell a refusal apart
    # from a real answer.
    def self.refusal?(content)
      content.is_a?(String) && content.present? && !content.include?("{")
    end

    # Send messages, return the response.
    #
    # schema:       a RubyLLM::Schema (or JSON-schema hash) for structured output.
    #               When given, the return value is the parsed object, not text.
    # expects_json: for prompt-driven JSON without a hard schema — a non-empty
    #               response with no "{" is logged as "refused" rather than
    #               "success", so refusals stay visible in the ledger.
    def chat(messages, operation:, role: nil, schema: nil, temperature: 1, max_tokens: nil, metadata: {}, expects_json: false)
      start_time  = Time.current
      prompt_text = normalize_prompt(messages)

      begin
        chat = RubyLLM.chat(model: @model, provider: "anthropic", assume_model_exists: true)
        chat = chat.with_temperature(temperature) if temperature
        chat = chat.with_params(max_tokens: max_tokens) if max_tokens
        chat = chat.with_schema(schema) if schema
        response = chat.ask(messages)

        content = response.content
        refused = schema.nil? && expects_json && self.class.refusal?(content)

        record_usage(
          operation: operation, role: role,
          input_tokens: response.input_tokens, output_tokens: response.output_tokens,
          duration_ms: elapsed_ms(start_time),
          status: refused ? "refused" : "success",
          metadata: metadata, prompt: prompt_text, response: stringify(content)
        )

        content
      rescue Faraday::TooManyRequestsError, RubyLLM::RateLimitError => e
        record_failure(operation, role, start_time, "rate_limited", metadata, prompt_text, e)
        raise LLM::RateLimitError, "Rate limited: #{e.message}"
      rescue StandardError => e
        record_failure(operation, role, start_time, "error", metadata, prompt_text, e)
        raise LLM::ApiError, "API error: #{e.message}"
      end
    end

    # Stream the response, yielding each text chunk. Returns the full text.
    def chat_stream(messages, operation:, role: nil, metadata: {}, &block)
      start_time    = Time.current
      prompt_text   = normalize_prompt(messages)
      full_response = +""

      begin
        chat = RubyLLM.chat(model: @model, provider: "anthropic", assume_model_exists: true)
        response = chat.ask(messages) do |chunk|
          next unless chunk.content && !chunk.content.empty?

          full_response << chunk.content
          block&.call(chunk.content)
        end

        record_usage(
          operation: operation, role: role,
          input_tokens: response.input_tokens, output_tokens: response.output_tokens,
          duration_ms: elapsed_ms(start_time),
          status: "success", metadata: metadata.merge(streamed: true),
          prompt: prompt_text, response: full_response
        )

        full_response
      rescue Faraday::TooManyRequestsError, RubyLLM::RateLimitError => e
        record_failure(operation, role, start_time, "rate_limited", metadata, prompt_text, e)
        raise LLM::RateLimitError, "Rate limited: #{e.message}"
      rescue StandardError => e
        record_failure(operation, role, start_time, "error", metadata, prompt_text, e)
        raise LLM::ApiError, "API error: #{e.message}"
      end
    end

    private

    def record_usage(operation:, role:, input_tokens:, output_tokens:, duration_ms:, status:, metadata: {}, error_message: nil, prompt: nil, response: nil)
      LLMUsage.create!(
        operation: operation, role: role&.to_s, model: @model,
        input_tokens: input_tokens || 0, output_tokens: output_tokens || 0,
        cost: LLM.config.calculate_cost(@model, input_tokens || 0, output_tokens || 0),
        duration_ms: duration_ms, status: status, metadata: metadata,
        error_message: error_message,
        # PostgreSQL rejects null bytes in text/jsonb columns — strip defensively.
        prompt: prompt&.delete("\x00"), response: response&.delete("\x00")
      )
    end

    def record_failure(operation, role, start_time, status, metadata, prompt_text, error)
      record_usage(
        operation: operation, role: role, input_tokens: 0, output_tokens: 0,
        duration_ms: elapsed_ms(start_time), status: status, metadata: metadata,
        error_message: error.message, prompt: prompt_text
      )
    end

    def elapsed_ms(start_time)
      ((Time.current - start_time) * 1000).to_i
    end

    def stringify(content)
      content.is_a?(String) ? content : content.to_json
    end

    def normalize_prompt(messages)
      case messages
      when String then messages
      when Array  then messages.map { |m| m.is_a?(Hash) ? "#{m[:role]}: #{m[:content]}" : m.to_s }.join("\n\n")
      else messages.to_s
      end
    end
  end
end
