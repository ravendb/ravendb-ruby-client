require 'net/http'
require 'database/exceptions'

class Net::HTTPResponse
  def json(raise_when_invalid = true)
    json = body

    if !json.is_a? Hash
      begin
        json = JSON.parse(json)
      rescue
        if raise_when_invalid
          raise ErrorResponseException, 'Not a valid JSON'  
        end  
      end  
    end  

    json
  end  
end  