require "json"
require 'net/http'
require 'database/exceptions'

class Net::HTTPResponse
  def json(raise_when_invalid = true)
    json = body

    if !json.is_a? Hash
      begin
        if json.is_a?(String) && !json.empty?
          json = JSON.parse(json)
        elsif
          json = nil
        end    
      rescue
        if raise_when_invalid
          raise RavenDB::ErrorResponseException, 'Not a valid JSON'  
        end  
      end  
    end  

    json
  end  
end  