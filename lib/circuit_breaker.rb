require_relative 'circuit_breaker/version'
require_relative 'circuit_breaker/configuration'
require_relative 'circuit_breaker/exceptions'
require_relative 'circuit_breaker/cache_helper'
require_relative 'circuit_breaker/notifier_helper'

module CircuitBreaker
  class << self
    include CircuitBreaker::CacheHelper
    include CircuitBreaker::NotifierHelper
    attr_reader :circuit, :circuit_options, :exceptions

    def run(circuit, options)
      initialize_circuit(circuit, options)
      return skip! if open?

      begin
        response = yield
        success!
      rescue *@exceptions
        failure!
        raise
      end
      response
    end

    def initialize_circuit(circuit, options)
      @circuit = circuit.to_s
      @circuit_options = options
      @exceptions = options.fetch(:exceptions)
      check_sleep_window
    end

    def open?
      key_exists_in_cache?(open_storage_key)
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    private

    def check_sleep_window
      return unless sleep_window < time_window

      warning_message = "sleep_window: #{sleep_window} is shorter than time_window: #{time_window}, "\
                        'the error_rate would not be reset after a sleep.'
      raise CircuitBreaker::InvalidOptionsError, warning_message
    end

    def skip!
      event_notifier.info("Circuit Breaker: skipping to execute circuit: #{circuit}. Circuit is open.\n")
      raise CircuitBreaker::OpenCircuitError, circuit
    end

    def success!
      increment_event('success')
      close! if half_open?
    end

    def close!
      return unless !open? && delete_from_cache(half_open_storage_key)

      event_notifier.info("Circuit Breaker: close! allowing to execute circuit: #{circuit} again\n")
    end

    def failure!
      increment_event('failure')
      open! if half_open? || should_open?
    end

    def open!
      open_circuit! unless open?
    end

    def half_open?
      key_exists_in_cache?(half_open_storage_key)
    end

    def should_open?
      aligned_time = align_time_to_window
      failures = event_in_time('failure', aligned_time)
      successes = event_in_time('success', aligned_time)
      passed_volume_threshold?(failures, successes) && passed_rate_threshold?(failures, successes)
    end

    def passed_volume_threshold?(failures, successes)
      failures + successes >= option_value('volume_threshold')
    end

    def passed_rate_threshold?(failures, successes)
      error_rate(failures, successes) >= option_value('error_threshold')
    end

    def open_circuit!
      write_to_cache(open_storage_key, value: true, options: { expires_in: sleep_window })
      write_to_cache(half_open_storage_key, value: true)
      log_circuit_open_error
    end

    def error_rate(failures = event_count('failure'), success = event_count('success'))
      return 0.0 unless (failures + success).positive?

      (failures / (failures + success).to_f) * 100
    end

    def event_in_time(event, time)
      fetch_from_cache(stat_storage_key(event, time), options: { raw: true }).to_i
    end

    def sleep_window
      option_value('sleep_window')
    end

    def time_window
      option_value('time_window')
    end

    def option_value(name)
      value = circuit_options.with_indifferent_access[name]
      value.is_a?(Proc) ? value.call : value
    end

    def increment_event(event)
      increment_in_cache(stat_storage_key(event), 1, options: { expires: time_window })
    end

    def align_time_to_window(window = time_window)
      time = Time.now.to_i
      time - (time % window)
    end
  end
end
