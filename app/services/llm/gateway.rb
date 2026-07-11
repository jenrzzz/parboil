module LLM
  # The hob-shaped seam. Callers talk to the gateway in terms of *roles* and
  # never touch a model ID or a provider API — exactly hob's client contract.
  # Today it resolves the role locally and calls Anthropic through LLM::Client;
  # when hob's gateway ships, the swap is replacing this module's internals with
  # the `hob` gem, leaving every call site untouched.
  #
  # Method map to the eventual hob client (see ~/Source/hob/DESIGN.md):
  #   Gateway.complete(role:, schema:, messages:)  ->  hob.complete(role:, schema:, messages:)
  #   Gateway.chat(role:, messages:) { |chunk| }   ->  hob.chat(...) { |event| }
  module Gateway
    module_function

    # Structured / one-shot completion. With a schema, returns the parsed object
    # (used for typed-node extraction); without one, returns text. `operation`
    # labels the call in the usage ledger; defaults to the role name.
    def complete(role:, messages:, schema: nil, operation: nil, **opts)
      client_for(role).chat(
        messages, operation: (operation || role).to_s, role: role, schema: schema, **opts
      )
    end

    # Streaming chat turn (the interview). Yields each text chunk; returns the
    # full text. The persona/system prompt is assembled by the caller and passed
    # in `messages` — personas stay local prompt material until hob owns them.
    def chat(role:, messages:, operation: nil, metadata: {}, &block)
      client_for(role).chat_stream(
        messages, operation: (operation || role).to_s, role: role, metadata: metadata, &block
      )
    end

    def client_for(role)
      Client.new(model: LLM.config.model_for(role))
    end
  end
end
