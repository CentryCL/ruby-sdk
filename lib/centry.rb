# frozen_string_literal: true

require 'net/http'
require 'net/https'
require 'json'

# Centry es un sencillo SDK sin dependencias con el cual se pueden hacer todo
# tipo de request a la API de Centry.
#
# https://centrycl.github.io/centry-rest-api-docs/
# https://github.com/CentryCL/ruby-sdk
class Centry

  attr_reader :client_id, :client_secret, :redirect_uri
  attr_accessor :access_token, :refresh_token, :token_type, :scope, :created_at, :expires_in

  # Constructor de la clase SDK.
  #
  # @param [String] client_id Identificador de la aplicación. Es generado por
  # Centry.
  # @param [String] client_secret Clave secreta de la aplicación. Es generado
  # por Centry, debe ser conocido sólo por la aplicación y Centry. Los usuarios
  # no tienen que tener acceso a este dato.
  # @param [String] redirect_uri URL a la que Centry enviará el código de
  # autorización como parámetro GET cada vez que un usuario autorice a ésta a
  # acceder a sus datos. Si se usa la URI `urn:ietf:wg:oauth:2.0:oob`, entonces
  # el código de autorización se mostrará en pantalla y el usuario deberá
  # copiarlo y pegarlo donde la aplicación pueda leerlo.
  # @param [String] access_token (opcional) Último access_token del que se tiene
  # registro. Si se entrega, entonces no es necesario que el usuario tenga que
  # volver a autorizar la aplicacción.
  # @param [String] refresh_token (opcional) Último refresh_token del que se
  # tiene registro.
  # @return [Centry] una nueva instancia del SDK.
  def initialize(
    client_id,
    client_secret,
    redirect_uri,
    access_token = nil,
    refresh_token = nil
  )
    @client_id = client_id
    @client_secret = client_secret
    @redirect_uri = redirect_uri
    @access_token = access_token
    @refresh_token = refresh_token
  end

  ##
  # Genera la URL con la que le pediremos a un usuario que nos entregue los
  # permisos de lectura y/o escritura a los recursos que se indican en el
  # parámetro <code>scope</code>.
  #
  # @param [String] scope Es la concatenación con un espacio de separación (" ")
  # de todos los ámbitos a los que se solicita permiso. Estos pueden ser:
  # * *public* Para acceder a la información publica de Centry como marcas, categorías, colores, tallas, etc.
  # * *read_orders* Para leer información de pedidos
  # * *write_orders* Para manipular o eliminar pedidos
  # * *read_products* Para leer información de productos y variantes
  # * *write_products* Para manipular o eliminar productos y variantes
  # * *read_integration_config* Para leer información de configuraciones de integraciones
  # * *write_integration_config* Para manipular o eliminar configuraciones de integraciones
  # * *read_user* Para leer información de usuarios de la empresa
  # * *write_user* Para manilupar o eliminar usuarios de la empresa
  # * *read_webhook* Para leer información de webhooks
  # * *write_webhook* Para manilupar o eliminar webhooks
  # @return [String] URL para redirigir a los usuarios y solicitarles la
  # autorización de acceso.
  def authorization_url(scope)
    params = {
      client_id: @client_id,
      redirect_uri: @redirect_uri,
      response_type: 'code',
      scope: scope
    }
    "https://www.centry.cl/oauth/authorize?#{URI.encode_www_form(params)}"
  end

  ##
  # Método encargado de hacer todo tipo de solicitudes a Centry, desde
  # autorizaciones hasta manipulación de inventario.
  #
  # @param [String] endpoint Ruta o recurso de la API.
  # @param [symbol] method Indica el método HTTP a usar. Las opciones son:
  # * +:get+
  # * +:post+
  # * +:put+
  # * +:delete+
  # Como es una API REST, estos métodos suelen estar asociados a la lectura,
  # creación, edición y eliminacion de recursos.
  # @param [Hash] params (opcional) Llaves y valores que irán en la URL como
  # parámetros GET
  # @param [Hash] payload (opcional) Body del request. El SDK se
  # encargará de transformarlo en un JSON.
  # @return [Net::HTTPResponse] resultado del request.
  def request(endpoint, method, params = {}, payload = {})
    query = params ? URI.encode_www_form(params) : ''
    uri = URI("https://www.centry.cl/#{endpoint}?#{query}")
    header = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    }
    req = case method
          when :get    then Net::HTTP::Get.new(uri, header)
          when :post   then Net::HTTP::Post.new(uri, header)
          when :put    then Net::HTTP::Put.new(uri, header)
          when :delete then Net::HTTP::Delete.new(uri, header)
    end
    req.add_field('Authorization', "Bearer #{@access_token}") unless PUBLIC_ENDPOINTS.include?(endpoint)

    req.body = JSON.generate(payload) if payload && payload != {}
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| return http.request(req) }
  end

  # Atajo para generar requests GET
  #
  # @param [String] endpoint Ruta o recurso de la API.
  # @param [Hash] params (opcional) Llaves y valores que irán en la URL como
  # parámetros GET
  # @return [Hash]
  def get(endpoint, params = {})
    request(endpoint, :get, params)
  end

  # Atajo para generar requests POST
  #
  # @param [String] endpoint Ruta o recurso de la API.
  # @param [Hash] params (opcional) Llaves y valores que irán en la URL como
  # parámetros GET
  # @param [Hash] payload (opcional) Body del request. El SDK se
  # encargará de transformarlo en un JSON.
  def post(endpoint, params = {}, payload = {})
    request(endpoint, :post, params, payload)
  end

  # Atajo para generar requests PUT
  #
  # @param [String] endpoint Ruta o recurso de la API.
  # @param [Hash] params (opcional) Llaves y valores que irán en la URL como
  # parámetros GET
  # @param [Hash] payload (opcional) Body del request. El SDK se
  # encargará de transformarlo en un JSON.
  def put(endpoint, params = {}, payload = {})
    request(endpoint, :put, params, payload)
  end

  # Atajo para generar requests DELETE
  #
  # @param [String] endpoint Ruta o recurso de la API.
  # @param [Hash] params (opcional) Llaves y valores que irán en la URL como
  # parámetros GET
  def delete(endpoint, params = {})
    request(endpoint, :delete, params, payload)
  end

  # Una vez que un usuario ha autorizado nuestra aplicación para que accceda a
  # su información, Centry genera un código de autorización con el cual podremos
  # solicitar el primer access_token y refresh_token. Éste método se encarga de
  # esta tarea por lo que se le debe entrecar el código de autorización como
  # parámetro.
  #
  # Se recomienda registrar estos tokens con algún mecanismo de persistencia
  # como una base de datos.
  #
  # @param [String] code Código de autorización generado por Centry depués de
  # que el usuario autorizó la aplicación.
  #
  # @see https://www.oauth.com/oauth2-servers/access-tokens/authorization-code-request/
  def authorize(code)
    grant('authorization_code', code: code)
  end

  # Un access_token tiene una vigencia de 7200 segudos (2 horas) por lo que una
  # vez cumplido ese plazo es necesario solicitar un nuevo token usando como
  # llave el refresh_token que teníamos registrado. Este método se encarga de
  # hacer esta renovacion de tokens.
  #
  # Se recomienda registrar estos nuevos tokens con algún mecanismo de
  # persistencia como una base de datos.
  #
  # @see https://www.oauth.com/oauth2-servers/access-tokens/authorization-code-request/
  def refresh
    grant('refresh_token', refresh_token: @refresh_token)
  end


  # Este mecanismo de autorización es utilizado en aplicaciones que requieren
  # acceso a sus propios recursos.
  #
  # @param [String] scope Es la concatenación con un espacio de separación (" ") de todos los ámbitos a
  # los que se solicita permiso. Estos pueden ser:
  # * *public* Para acceder a la información publica de Centry como marcas, categorías, colores, tallas, etc.
  # * *read_orders* Para leer información de pedidos
  # * *write_orders* Para manipular o eliminar pedidos
  # * *read_products* Para leer información de productos y variantes
  # * *write_products* Para manipular o eliminar productos y variantes
  # * *read_integration_config* Para leer información de configuraciones de integraciones
  # * *write_integration_config* Para manipular o eliminar configuraciones de integraciones
  # * *read_user* Para leer información de usuarios de la empresa
  # * *write_user* Para manilupar o eliminar usuarios de la empresa
  # * *read_webhook* Para leer información de webhooks
  # * *write_webhook* Para manilupar o eliminar webhooks
  #
  # @see https://www.oauth.com/oauth2-servers/access-tokens/client-credentials/
  def client_credentials(scope = nil)
    grant(
      'client_credentials',
      scope.nil? || scope.strip == '' ? {} : { scope: scope }
    )
  end

  private

  # Endpoints de la API de Centry que no requieren de un access_token.
  PUBLIC_ENDPOINTS = [
    'oauth/token'
  ].freeze

  def grant(grant_type, extras)
    payload = {
      client_id: @client_id,
      client_secret: @client_secret,
      redirect_uri: @redirect_uri,
      grant_type: grant_type
    }.merge(extras)

    response = JSON.parse post('oauth/token', nil, payload).body

    @access_token = response['access_token']
    @refresh_token = response['refresh_token']
    @token_type = response['token_type']
    @scope = response['scope']
    @created_at = response['created_at']
    @expires_in = response['expires_in']
  end

end
