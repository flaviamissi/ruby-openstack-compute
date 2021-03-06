module OpenStack
module Compute

  class Authentication

    # Performs an authentication to the OpenStack auth server.
    # If it succeeds, it sets the svrmgmthost, svrmgtpath, svrmgmtport,
    # svrmgmtscheme, authtoken, and authok variables on the connection.
    # If it fails, it raises an exception.
    def self.init(conn)
      if conn.auth_path =~ /.*v2.0\/?$/
        AuthV20.new(conn)
      else
        AuthV10.new(conn)
      end
    end

  end

  private
  class AuthV20
    
    def initialize(connection)
      begin
        server = Net::HTTP::Proxy(connection.proxy_host, connection.proxy_port).new(connection.auth_host, connection.auth_port)
        if connection.auth_scheme == "https"
          server.use_ssl = true
          server.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        server.start
      rescue
        raise OpenStack::Compute::Exception::Connection, "Unable to connect to #{server}"
      end

      auth_data = JSON.generate({ "auth" =>  { "passwordCredentials" => { "username" => connection.authuser, "password" => connection.authkey }}})
      response = server.post(connection.auth_path.chomp("/")+"/tokens", auth_data, {'Content-Type' => 'application/json'})
      if (response.code =~ /^20./)
        resp_data=JSON.parse(response.body)
        connection.authtoken = resp_data['access']['token']['id']
        resp_data['access']['serviceCatalog'].each do |service|
          if service['type'] == connection.service_name
            uri = String.new
            endpoints = service["endpoints"]
            if connection.region
              endpoints.each do |ep|
                if ep["region"].upcase == connection.region.upcase
                  uri = URI.parse(ep["publicURL"])
                end
              end
              if uri == ''
                raise OpenStack::Compute::Exception::Authentication, "No API endpoint for region #{connection.region}"
              end
            else
              uri = URI.parse(endpoints[0]["publicURL"])
            end
            connection.svrmgmthost = uri.host
            connection.svrmgmtpath = uri.path
            connection.svrmgmtport = uri.port
            connection.svrmgmtscheme = uri.scheme
            connection.authok = true
          end
        end
      else
        connection.authtoken = false
        raise OpenStack::Compute::Exception::Authentication, "Authentication failed with response code #{response.code}"
      end
      server.finish
    end
  end

  class AuthV10
    
    def initialize(connection)
      hdrhash = { "X-Auth-User" => connection.authuser, "X-Auth-Key" => connection.authkey }
      begin
        server = Net::HTTP::Proxy(connection.proxy_host, connection.proxy_port).new(connection.auth_host, connection.auth_port)
        if connection.auth_scheme == "https"
          server.use_ssl = true
          server.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        server.start
      rescue
        raise OpenStack::Compute::Exception::Connection, "Unable to connect to #{server}"
      end
      response = server.get(connection.auth_path, hdrhash)
      if (response.code =~ /^20./)
        connection.authtoken = response["x-auth-token"]
        uri = URI.parse(response["x-server-management-url"])
        connection.svrmgmthost = uri.host
        connection.svrmgmtpath = uri.path
        # Force the path into the v1.1 URL space
        connection.svrmgmtpath.sub!(/\/.*\/?/, '/v1.1/')
        connection.svrmgmtpath += connection.authtenant
        connection.svrmgmtport = uri.port
        connection.svrmgmtscheme = uri.scheme
        connection.authok = true
      else
        connection.authtoken = false
        raise OpenStack::Compute::Exception::Authentication, "Authentication failed with response code #{response.code}"
      end
      server.finish
    end
  end

end
end
