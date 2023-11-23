# frozen_string_literal: true

require_relative "circuit_breaker/version"
require_relative "circuit_breaker/configuration"

module CircuitBreaker
  class << self
    attr_reader :circuit, :circuit_options, :exceptions
    attr_accessor :event_notifier, :circuit_open_notifier, :cache_storage

    def event_notifier
      CircuitBreaker.configuration.event_notifier
    end

    def circuit_open_notifier
      CircuitBreaker.configuration.circuit_open_notifier
    end

    def cache_storage
      CircuitBreaker.configuration.cache_storage
    end
    
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def open_storage_key
      "circuits:#{circuit}:open"
    end

    def half_open_storage_key
      "circuits:#{circuit}:half_open"
    end

    def option_value(name)
      value = circuit_options.with_indifferent_access[name]
      value.is_a?(Proc) ? value.call : value
    end

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
      @open_storage_key = "circuits:#{circuit}:open"
      @half_open_storage_key = "circuits:#{circuit}:half_open"
      check_sleep_window
    end

    def open?
      key_exists_in_cache?(@open_storage_key)
    end

    private

    def skip!
      event_notifier.info("Circuit Breaker: skipping to execute circuit: #{circuit}. Circuit is open.\n")
      raise Exceptions::OpenCircuitError, circuit
    end

    def success!
      increment_event('success')
      close! if half_open?
    end

    def close!
      return unless !open? && Rails.cache.delete(@half_open_storage_key)
      event_notifier.info("Circuit Breaker: close! allowing to execute circuit: #{circuit} again\n")
    end

    def half_open?
      key_exists_in_cache?(@half_open_storage_key)
    end

    def failure!
      increment_event('failure')
      return open! if half_open? || should_open?
    end

    def open!
      open_circuit! unless open?
    end

    def error_rate(failures = event_count('failure'), success = event_count('success'))
      return 0.0 unless (failures + success).positive?
      (failures / (failures + success).to_f) * 100
    end

    def event_count(type)
      cache_storage.load(stat_storage_key(type), raw: true).to_i
    end

    def should_open?
      aligned_time = align_time_to_window
      failures = event_in_time('failure', aligned_time)
      successes = event_in_time('success', aligned_time)
      passed_volume_threshold?(failures, successes) && passed_rate_threshold?(failures, successes)
    end

    def event_in_time(event, time)
      fetch_from_cache(stat_storage_key(event, time), options: { raw: true }).to_i
    end

    def passed_volume_threshold?(failures, successes)
      failures + successes >= option_value('volume_threshold')
    end

    def passed_rate_threshold?(failures, successes)
      error_rate(failures, successes) >= option_value('error_threshold')
    end

    def open_circuit!
      write_to_cache(@open_storage_key, value: true,
                                        options: { expires_in: option_value('sleep_window') })
      write_to_cache(@half_open_storage_key, value: true)
      log_circuit_open_error
    end

    def increment_event(event)
      time_window = option_value('time_window')
      increment_in_cache(stat_storage_key(event), 1, options: { expires: time_window })
    end

    def stat_storage_key(event, aligned_time = align_time_to_window)
      "circuits:#{circuit}:stats:#{aligned_time}:#{event}"
    end

    def align_time_to_window(window = option_value('time_window'))
      time = Time.now.to_i
      time - (time % window)
    end

    def log_circuit_open_error
      aligned_time = align_time_to_window
      failures = event_in_time('failure', aligned_time)
      successes = event_in_time('success', aligned_time)
      event_notifier.info("Circuit Breaker: open! will stop to execute circuit: #{circuit}\n"\
      "Number of failures: #{failures}, rate: #{error_rate(failures, successes)}, "\
      "in #{option_value('time_window')} seconds")
      circuit_open_notifier.warning('Circuit Open', circuit: circuit, failures: failures,
                                      successes: successes, rate: error_rate(failures, successes),
                                      time_window: option_value('time_window'))
    end

    def check_sleep_window
      sleep_window = option_value('sleep_window')
      time_window  = option_value('time_window')
      return unless sleep_window < time_window

      warning_message = "sleep_window: #{sleep_window} is shorter than time_window: #{time_window}, "\
                        "the error_rate would not be reset after a sleep."
      raise InvalidCircuitBreakerOptions, warning_message
    end

    def fetch_from_cache(key, options: {})
      cache_storage.fetch(key, options)
    end

    def write_to_cache(key, value: nil, options: {})
      cache_storage.write(key, value, options)
    end

    def key_exists_in_cache?(key, namespace: nil)
      cache_storage.exist?(key, namespace: namespace)
    end

    def increment_in_cache(key, increment, options: {})
      value = key_exists_in_cache?(key) ? fetch_from_cache(key, options: { raw: true }).to_i : 0
      write_to_cache(key, value: value + increment, options: options.merge({ raw: true }))
    end
  end
end
