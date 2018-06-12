require "active_support/cache"
require "active_support/cache/memory_store"

module RavenDB
  class HttpCache
    def initialize(size:)
      @items = ActiveSupport::Cache::MemoryStore.new(size: size)
    end

    def set(url, change_vector, result)
      http_cache_item = HttpCacheItem.new
      http_cache_item.change_vector = change_vector
      http_cache_item.payload = result
      # http_cache_item.cache = self # disabled because of Marshal

      @items.put(url, http_cache_item)
    end

    def get(url, change_vector_ref, response_ref)
      item = items[url]
      unless item.nil?
        change_vector_ref.value = item.change_vector
        response_ref.value = item.payload

        return ReleaseCacheItem.new(item)
      end

      change_vector_ref.value = nil
      response_ref.value = nil
      ReleaseCacheItem(nil).new
    end

    def not_found=(url)
      http_cache_item = HttpCacheItem.new
      http_cache_item.change_vector = "404 response"
      @items.write(url, http_cache_item)
    end

    class ReleaseCacheItem
      def initialize(item)
        @item = item
      end

      def not_modified
        unless @item.nil?
          @item.last_server_update = DateTime.now
        end
      end

      def age
        if @item.nil?
          return Float::INFINITY
        end
        DateTime.now - item.lastServerUpdate
      end

      def might_have_been_modified
        false # TBD
      end
    end
  end
end
