# frozen_string_literal: true

require 'minitest/autorun'
require 'cgi'
require 'centry'

class CentryTest < Minitest::Test
  def setup
    @client_id = '4f3d8e65a417c386ab76a6550974a26713c811c5b81c1f0fa2e7726562fbb702'
    @client_secret = '13b1549e58c36acfe7e43345676b58e428288116f06f818a631fb12fc447faf2'
    @redirect_uri = 'urn:ietf:wg:oauth:2.0:oob'
    @authorization_code = '0a912c737b7262cee3a5970a02e11a83108f16fb2f8793ba2538bf44f8ea4f2d'
    @sdk = Centry.new(@client_id, @client_secret, @redirect_uri)
  end

  def test_authorization
    # test_authorization_url
    expected_authorization_url = 'https://www.centry.cl/oauth/authorize?' \
                                 "client_id=#{@client_id}&" \
                                 "redirect_uri=#{CGI.escape(@redirect_uri)}&" \
                                 'response_type=code&scope=public+read_orders'
    assert_equal expected_authorization_url,
                 @sdk.authorization_url('public read_orders')

    # test_authorize
    @sdk.authorize(@authorization_code)
    assert_equal false, @sdk.access_token.empty? || @sdk.refresh_token.empty?

    # test_refresh
    old_access_token = @sdk.access_token
    @sdk.refresh
    assert old_access_token != @sdk.access_token

    # test_list_code
    assert_equal '200',
                 @sdk.request('conexion/v1/sizes.json', :get, limit: 5).code

    # test_list_sizes
    assert_equal 5, JSON.parse(
      @sdk.request('conexion/v1/sizes.json', :get, limit: 5).body
    ).length
  end

  def test_client_credentials
    # test_authorize
    @sdk.client_credentials('public read_orders write_webhook')
    assert_equal false, @sdk.access_token.empty?
    assert_equal 'public read_orders write_webhook', @sdk.scope

    # test_list_code
    assert_equal '200', @sdk.get('conexion/v1/orders.json', limit: 5).code

    # test_list_sizes
    assert_equal 5, JSON.parse(
      @sdk.get('conexion/v1/sizes.json', limit: 5).body
    ).length
  end
end
