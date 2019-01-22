require 'minitest/autorun'
require 'centry'

class CentryTest < Minitest::Test
  def setup
    @sdk = Centry.new(
      "client_id",
      "client_secret",
      "urn:ietf:wg:oauth:2.0:oob"
    )
  end

  def test_authorization
    # test_authorization_url
    assert_equal "https://www.centry.cl/oauth/authorize?client_id=client_id&redirect_uri=urn%3Aietf%3Awg%3Aoauth%3A2.0%3Aoob&response_type=code&scope=public+read_orders",
    @sdk.authorization_url("public read_orders")

    # test_authorize
    @sdk.authorize("code")
    assert_equal true, @sdk.access_token.length > 0 && @sdk.refresh_token.length > 0

    # test_refresh
    old_access_token = @sdk.access_token
    @sdk.refresh
    assert old_access_token != @sdk.access_token

    # test_list_code
    assert_equal "200", @sdk.request("conexion/v1/sizes.json", :get, {limit: 5}).code

    # test_list_sizes
    assert_equal 5, JSON.parse(@sdk.request("conexion/v1/sizes.json", :get, {limit: 5}).body).length
  end

  def test_client_credentials
    # test_authorize
    @sdk.client_credentials
    assert_equal true, @sdk.access_token.length > 0

    # test_list_code
    assert_equal "200", @sdk.request("conexion/v1/sizes.json", :get, {limit: 5}).code

    # test_list_sizes
    assert_equal 5, JSON.parse(@sdk.request("conexion/v1/sizes.json", :get, {limit: 5}).body).length
  end
end
