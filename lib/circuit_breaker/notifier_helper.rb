module CircuitBreaker
  module NotifierHelper
    def event_notifier
      CircuitBreaker.configuration.event_notifier
    end

    def circuit_open_notifier
      CircuitBreaker.configuration.circuit_open_notifier
    end

    def log_circuit_open_error
      aligned_time = align_time_to_window
      failures = event_in_time('failure', aligned_time)
      successes = event_in_time('success', aligned_time)
      event_notifier.info("Circuit Breaker: open! will stop to execute circuit: #{circuit}\n"\
      "Number of failures: #{failures}, rate: #{error_rate(failures,
                                                           successes)}, in #{time_window} seconds")
      log_in_circuit_open_notifier(failures, successes)
    end

    def log_in_circuit_open_notifier(failures, successes)
      circuit_open_notifier.warning("Circuit Open for utility #{@utility.code} - #{@utility.name}",
                                    service: @service, utility: @utility,
                                    time_window: option_value('time_window'),
                                    rate: error_rate(failures, successes),
                                    failures: failures, successes: successes)
    end
  end
end
