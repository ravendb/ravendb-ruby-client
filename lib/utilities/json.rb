require "json"
require 'net/http'
require 'database/exceptions'

class Net::HTTPResponse
  def json(raise_when_invalid = true)
    json = body
    parsed = nil

    if !json.is_a? Hash
      begin
        if json.is_a?(String) && !json.empty?
          parsed = JSON.parse(json)
        end
      rescue
        if raise_when_invalid
          raise RavenDB::ErrorResponseException, 'Not a valid JSON'  
        end  
      end  
    end  

    parsed
  end  
end  