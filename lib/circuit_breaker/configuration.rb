module CircuitBreaker
  class Configuration
    attr_accessor :event_notifier, :circuit_open_notifier, :cache_storage

    def initialize
      @event_notifier = Rails.logger
      @circuit_open_notifier = Rollbar
      @cache_storage = Rails.cache
    end
  end
end
