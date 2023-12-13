module CircuitBreaker
  module CacheHelper
    def cache_storage
      CircuitBreaker.configuration.cache_storage
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

    def delete_from_cache(key)
      cache_storage.delete(key)
    end

    def event_count(type)
      cache_storage.load(stat_storage_key(type), raw: true).to_i
    end

    def open_storage_key
      "circuits:#{circuit}:open"
    end

    def half_open_storage_key
      "circuits:#{circuit}:half_open"
    end

    def stat_storage_key(event, aligned_time = align_time_to_window)
      "circuits:#{circuit}:stats:#{aligned_time}:#{event}"
    end
  end
end
