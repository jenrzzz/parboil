module LLM
  # The one call shape parboil uses: a role, a system prompt, a user prompt,
  # and optionally a schema. `operation`, `metadata` and `ref` are ledger
  # fields hob groups usage on. Every hob error becomes LLM::Error so the
  # controllers' rescue stays one line.
  module Gateway
    module_function

    # With a schema, returns the parsed object (string keys); without one,
    # the reply text.
    def complete(role:, messages:, system: nil, schema: nil, operation: nil, metadata: {}, ref: nil)
      completion = LLM.client.complete(
        role: role.to_s, system: system, messages: normalize(messages), schema: schema,
        operation: (operation || role).to_s, metadata: metadata, ref: ref, realm: LLM::REALM
      )
      return completion.content.to_s unless schema

      completion.parsed or raise Error, "no structured content in the reply"
    rescue Hob::Refused => e
      raise Error, "the model declined (#{e.message})"
    rescue Hob::RateLimited => e
      raise Error, "rate limited: #{e.message}"
    rescue Hob::Unauthorized => e
      raise Error, "bad hob key: #{e.message}"
    rescue Hob::Error => e
      raise Error, "hob error: #{e.message}"
    end

    # The persona renders one user prompt as a string; a caller may also pass
    # a messages array through untouched.
    def normalize(messages)
      messages.is_a?(String) ? [ { role: "user", content: messages } ] : messages
    end
  end
end
