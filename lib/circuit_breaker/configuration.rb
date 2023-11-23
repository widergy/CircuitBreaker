module CircuitBreaker
  class InvalidCircuitBreakerOptions < StandardError; end

  class Configuration

    DEFAULT_EVENT_NOTIFIER = Rails.logger
    DEFAULT_CIRCUIT_OPEN_NOTIFIER = Rails.logger

    attr_accessor :event_notifier, :circuit_open_notifier, :cache_storage

    def initialize
        @event_notifier  = DEFAULT_EVENT_NOTIFIER
        @circuit_open_notifier = DEFAULT_CIRCUIT_OPEN_NOTIFIER
        @cache_storage = Rails.cache
    end
  end
end
