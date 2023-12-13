require 'spec_helper'
require 'net/http'
require 'net/https'
require_relative '../lib/circuit_breaker/exceptions'

RSpec.describe CircuitBreaker do
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:cache) { Rails.cache }
  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    allow(described_class).to receive(:cache_storage).and_return(cache)
    cache.clear
    allow(service).to receive(:call).and_return(service_result)
  end

  let(:service) { proc { 1 + 2 } }
  let(:exceptions) { [Net::OpenTimeout, Net::ReadTimeout] }
  let(:exception) { exceptions.sample }
  let(:options) { circuit_options.merge({ exceptions: exceptions }) }
  let(:circuit_options) do
    {
      time_window: time_window, volume_threshold: volume_threshold,
      sleep_window: sleep_window, error_threshold: error_threshold
    }.as_json
  end

  let(:time_window) { 100 }
  let(:volume_threshold) { 1 }
  let(:sleep_window) { 200 }
  let(:error_threshold) { 50 }
  let(:url) { Faker::Internet.url }

  let(:aligned_time) { Time.now.to_i - (Time.now.to_i % time_window) }
  let(:cache_key_prefix) { "circuits:#{url}:stats:#{aligned_time}" }
  let(:service_result) { true }

  subject(:run_circuit) do
    proc { described_class.run(url, options) { service.call } }
  end

  context 'when circuit service does not exists' do
    let(:cache_key) { "#{cache_key_prefix}:success" }

    it 'writes circuit stats key in cache' do
      expect { run_circuit.call }
        .to(change { cache.exist?(cache_key) }.from(false).to(true))
    end

    let(:initial_value) { nil }
    let(:final_value) { 1 }

    it 'changes cache key value' do
      expect { run_circuit.call }
        .to change { cache.fetch(cache_key, options: { raw: true }) }.from(initial_value).to(final_value)
    end
  end

  context 'when citcuit service already exists with success' do
    let(:cache_key) { "#{cache_key_prefix}:success" }
    let(:initial_value) { Faker::Number.number(digits: 1).to_i }
    let(:final_value) { initial_value + 1 }
    before do
      cache.write(cache_key, initial_value, options: { expires: time_window })
    end

    it 'changes cache key value' do
      expect { run_circuit.call }
        .to change { cache.fetch(cache_key, options: { raw: true }) }.from(initial_value).to(final_value)
    end
  end

  context 'when the circuit service is open' do
    before do
      Rails.cache.write("circuits:#{url}:open", value: true, options: { expires: sleep_window })
    end

    it 'raises OpenCircuitError exception when circuit is performed' do
      expect { run_circuit.call }.to raise_error(CircuitBreaker::OpenCircuitError)
    end
  end

  context 'when the circuit service is closed and an exception is raised' do
    before do
      allow(service).to receive(:call).and_raise(exception)
    end

    context 'without previous circuit service failures' do
      let(:cache_key) { "#{cache_key_prefix}:failure" }

      it 'raises original exception and increment failures count' do
        expect { run_circuit.call }.to raise_error(exception)
          .and change { cache.fetch(cache_key, options: { raw: true }) }.from(nil).to(1)
      end
    end

    context 'with previous circuit service failures' do
      before do
        cache.write("#{cache_key_prefix}:failure", 10, { expires: time_window })
        cache.write("#{cache_key_prefix}:success", 0, { expires: time_window })
      end

      let(:cache_key) { "circuits:#{url}:open" }

      it 'raises original exception and opens the circuit service' do
        expect { run_circuit.call }.to raise_error(exception)
          .and change { cache.fetch(cache_key, options: { raw: true }) }.to(true)
      end
    end
  end

  context 'when the circuit service is half_open' do
    before do
      cache.write("circuits:#{url}:half_open", true, { expires: sleep_window })
    end

    context 'when the circuit service fails' do
      before do
        allow(service).to receive(:call).and_raise(exception)
      end

      let(:cache_key) { "circuits:#{url}:open" }

      it 'raises original exception and opens the circuit service' do
        expect { run_circuit.call }.to raise_error(exception)
          .and change { cache.fetch(cache_key, options: { raw: true }) }.to(true)
      end
    end

    context 'when the circuit service succeds' do
      before do
        allow(service).to receive(:call).and_return(true)
      end

      let(:cache_key) { "circuits:#{url}:half_open" }

      it 'closes the circuit and removes the half_open status' do
        expect { run_circuit.call }
          .to change { cache.fetch(cache_key, options: { raw: true }) }.from(true).to(nil)
      end
    end
  end
end
