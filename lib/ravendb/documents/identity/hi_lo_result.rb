module RavenDB
  class HiLoResult
    attr_accessor :prefix
    attr_accessor :low
    attr_accessor :high
    attr_accessor :last_size
    attr_accessor :server_tag
    attr_accessor :last_range_at
  end
end
