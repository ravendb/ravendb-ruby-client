module RavenDB
  class ServerNode
    @url = ''
    @database = nil
    @cluster_tag = nil

    def self.from_json(json)      
      node = self.new
      node.from_json(json)

      return node
    end

    def url
      @url
    end

    def database
      @database
    end

    def cluster_tag
      @cluster_tag
    end

    def initialize(url = '', database = nil, cluster_tag = nil)
      @url = url
      @database = database
      @cluster_tag = cluster_tag
    end  

    def from_json(json)     
      raise ArgumentError, 'Argument "json" should be an hash object' unless json.is_a? Hash
      
      @url = json["Url"]
      @database = json["Database"]
      @cluster_tag = json["ClusterTag"]
    end
  end
end 