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
      "Number of failures: #{failures}, rate: #{error_rate(failures, successes)}, in #{time_window} seconds")
      circuit_open_notifier.info('Circuit Open:', circuit: circuit, time_window: time_window, failures: failures,
                                                  successes: successes, rate: error_rate(failures, successes))
    end
  end
end
