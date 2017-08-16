module RavenDB
  class ApiKeyDefinition
    def initialize(enabled = true, secret = nil, server_admin = false, resources_access_mode = nil)
      if resources_access_mode
        resources_access_mode.each do |resource, mode|
          if !resource.start_with?('db/')
            raise InvalidOperationException, 'Resource name in ApiKeyDefinition should stars with "db/"'
          end
        end  
      end  

      @enabled = enabled
      @secret = secret
      @server_admin = server_admin
      @resources_access_mode = resources_access_mode || {}
    end

    def to_json
      return {
        "Enabled" => @enabled,
        "ResourcessAccessMode" => @resources_access_mode,
        "Secret" => @secret,
        "ServerAdmin" => @server_admin
      }
    end
  end
end