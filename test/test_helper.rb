ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # The one LLM seam tests need: Gateway.complete returns a canned reply
    # for the duration of the block. (minitest/mock left core in minitest 6,
    # and this is too small to warrant the gem.)
    def stub_llm_complete(reply)
      original = LLM::Gateway.method(:complete)
      LLM::Gateway.define_singleton_method(:complete) { |**_opts| reply }
      yield
    ensure
      LLM::Gateway.define_singleton_method(:complete, original)
    end
  end
end
