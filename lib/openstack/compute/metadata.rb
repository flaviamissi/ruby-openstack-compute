module OpenStack
module Compute

  class Metadata

    def initialize(connection, parent_url, metadata=nil)
      @connection = connection
      @base_url = "#{parent_url}/metadata"
      @metadata = metadata
    end

    def [](key)
      refresh if @metadata.nil?
      @metadata[key]
    end

    def []=(key, value)
      @metadata = {} if @metadata.nil?
      @metadata[key] = value
    end

    def store(key, value)
      @metadata = {} if @metadata.nil?
      @metadata[key] = value
    end

    def each_pair
      @metadata = {} if @metadata.nil?
      @metadata.each_pair do |k,v|
          yield k, v
      end
    end

    def size
      @metadata = {} if @metadata.nil?
      @metadata.size
    end

    def each
      refresh if @metadata.nil?
      @metadata.each
    end

    def save
      return if @metadata.nil?
      json = JSON.generate(:metadata => @metadata)
      response = @connection.req('PUT', @base_url, :data => json)
      @metadata = JSON.parse(response.body)['metadata']
    end

    def update(keys=nil)
      return if @metadata.nil?
      if keys.nil?
        json = JSON.generate(:metadata => @metadata)
        response = @connection.req('POST', @base_url, :data => json)
        @metadata = JSON.parse(response.body)['metadata']
      else
        if keys.kind_of? Array
          keys.each { |key|
            next if not @metadata.has_key?(key)
            update_key(key)
          }
        else
          return if not @metadata.has_key?(keys)
          update_key(keys)
        end
      end
    end

    def update_key(key)
      json = JSON.generate(:meta => { key => @metadata[key] })
      @connection.req('PUT', "#{@base_url}/#{key}", :data => json)
    end

    def refresh(keys=nil)
      if keys.nil?
        response = @connection.req('GET', @base_url)
        @metadata = JSON.parse(response.body)['metadata']
      else
        @metadata = {} if @metadata == nil
        if keys.kind_of? Array
          keys.each { |key|
            refresh_key(key)
          }
        else
          refresh_key(keys)
        end
      end
    end

    def refresh_key(key)
      response = @connection.req('GET', "#{@base_url}/#{key}")
      return if response.code == "404"
      meta = JSON.parse(response.body)['meta']
      meta.each { |k, v| @metadata[k] = v }
    end

    def delete(keys)
      if keys.kind_of? Array
        keys.each { |key|
          delete_key key
        }
      else
          delete_key keys
      end
    end

    def delete!(keys)
      if keys.kind_of? Array
        keys.each { |key|
          delete_key key do
            @connection.req('DELETE', "#{@base_url}/#{key}")
          end
        }
      else
          delete_key keys do
            @connection.req('DELETE', "#{@base_url}/#{keys}")
          end
      end
    end

    def delete_key(key, &block)
      return if @metadata.nil?
      block.call if block
      @metadata.delete(key)
    end

    def clear
      if @metadata.nil?
        @metadata = {}
      else
        @metadata.clear
      end
    end

    def clear!
      clear
      save
    end

    def has_key?(key)
      return False if @metadata.nil?
      return @metadata.has_key?(key)
    end

  end

end
end
