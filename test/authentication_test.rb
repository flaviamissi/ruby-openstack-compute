require 'net/http'
require 'ostruct'
require 'json'
require File.dirname(__FILE__) + '/test_helper'


class AuthenticationTest < Test::Unit::TestCase

  def test_good_authentication
    response = {'x-server-management-url' => 'http://server-manage.example.com/path', 'x-auth-token' => 'dummy_token'}
    response.stubs(:code).returns('204')
    server = mock(:use_ssl= => true, :verify_mode= => true, :start => true, :finish => true)
    server.stubs(:get).returns(response)
    Net::HTTP.stubs(:new).returns(server)
    connection = stub(:authuser => 'good_user', :authtenant => 'good_tenant', :authkey => 'bad_key', :auth_host => "a.b.c", :auth_port => "443", :auth_scheme => "https", :auth_path => "/v1.0", :authok= => true, :authtoken= => true, :svrmgmthost= => "", :svrmgmtpath= => "", :svrmgmtpath => "", :svrmgmtport= => "", :svrmgmtscheme= => "", :proxy_host => nil, :proxy_port => nil, :api_path => '/foo')
    result = OpenStack::Compute::Authentication.init(connection)
    assert_equal result.class, OpenStack::Compute::AuthV10
  end

  def test_bad_authentication
    response = mock()
    response.stubs(:code).returns('499')
    server = mock(:use_ssl= => true, :verify_mode= => true, :start => true)
    server.stubs(:get).returns(response)
    Net::HTTP.stubs(:new).returns(server)
    connection = stub(:authuser => 'bad_user', :authtenant => 'good_tenant', :authkey => 'bad_key', :auth_host => "a.b.c", :auth_port => "443", :auth_scheme => "https", :auth_path => "/v1.0", :authok= => true, :authtoken= => true, :proxy_host => nil, :proxy_port => nil, :api_path => '/foo')
    assert_raises(OpenStack::Compute::Exception::Authentication) do
      result = OpenStack::Compute::Authentication.init(connection)
    end
  end

  def test_bad_hostname
    Net::HTTP.stubs(:new).raises(OpenStack::Compute::Exception::Connection)
    connection = stub(:authuser => 'bad_user', :authtenant => 'good_tenant', :authkey => 'bad_key', :auth_host => "a.b.c", :auth_port => "443", :auth_scheme => "https", :auth_path => "/v1.0", :authok= => true, :authtoken= => true, :proxy_host => nil, :proxy_port => nil, :api_path => '/foo')
    assert_raises(OpenStack::Compute::Exception::Connection) do
      result = OpenStack::Compute::Authentication.init(connection)
    end
  end

end


class AuthenticationV20Test < Test::Unit::TestCase

  class RequestMock < OpenStruct
      attr_accessor :data

      def post path, data, headers
        @data = JSON.parse(data)
        self
      end

      def code
        "200"
      end

      def body
        '{"access": {"token": {"expires": "2012-01-12T11:12:31", "id": "8aa96665-62b0-4806-b793-59e4812aa76b"}, "user": {"id": "2", "roles": [], "name": "demo"}, "serviceCatalog": []}}'
      end
  end

  def setup
    @connection = stub(:authuser => 'bad_user', :authtenant => 'good_tenant', :authkey => 'bad_key',
                      :auth_host => "a.b.c", :auth_port => "443", :auth_scheme => "http",
                      :auth_path => "/v2.0", :authok= => true, :authtoken= => true, :proxy_host => nil,
                      :proxy_port => nil, :api_path => '/foo')
    @request = RequestMock.new
  end

  def test_should_use_tenantauth_when_post_to_request
    Net::HTTP.stubs(:new).returns(@request)
    result = OpenStack::Compute::Authentication.init(@connection)
    assert(@request.data["auth"]["passwordCredentials"].has_key? "tenantName")
  end

end
