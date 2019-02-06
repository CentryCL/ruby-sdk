require 'net/http'
require 'net/https'
require 'json'

class Centry
  PUBLIC_ENDPOINTS = [
    "oauth/token"
  ]

  attr_reader :client_id, :client_secret, :redirect_uri
  attr_accessor :access_token, :refresh_token, :token_type, :scope, :created_at, :expires_in

  ##
  # Constructor de la clase SDK.
  # @var client_id Identificador de la aplicación. Es generado por Centry.
  # @var client_secret Clave secreta de la aplicación. Es generado por Centry, debe ser conocido sólo por la aplicación y
  #                   Centry. Los usuarios no tienen que tener acceso a este dato.
  # @var redirect_uri URL a la que Centry enviará el código de autorización como parámetro GET cada vez que un usuario
  #                  autorice a ésta a acceder a sus datos. Si se usa la URI `urn:ietf:wg:oauth:2.0:oob`, entonces el
  #                  código de autorización se mostrará en pantalla y el usuario deberá copiarlo y pegarlo donde la
  #                  aplicación pueda leerlo.
  # @var access_token (opcional) Último access_token del que se tiene registro. Si se entrega, entonces no es necesario que el usuario tenga que volver a autorizar la aplicacción.
  # @var refresh_token (opcional) Último refresh_token del que se tiene registro.
  def initialize(client_id, client_secret, redirect_uri, access_token = nil, refresh_token = nil)
    @client_id = client_id
    @client_secret = client_secret
    @redirect_uri = redirect_uri
    @access_token = access_token
    @refresh_token = refresh_token
  end

  ##
  # Genera la URL con la que le pediremos a un usuario que nos entregue los permisos
  # de lecturo y/o escritura a los recursos que se indican en el parámetro <code>scope</code>
  # @var code Es la concatenación con un espacio de separación (" ") de todos los ámbitos a
  # los que se solicita permiso. Estos pueden ser:
  # <ul>
  #   <li><b>public</b> Para acceder a la información publica de Centry como marcas, categorías, colores, tallas, etc.</li>
  #   <li><b>read_orders</b> Para leer información de pedidos</li>
  #   <li><b>write_orders</b> Para manulupar o eliminar pedidos</li>
  #   <li><b>read_products</b>Para leer información de productos y variantes</li>
  #   <li><b>write_products</b>Para manulupar o eliminar productos y variantes</li>
  #   <li><b>read_integration_config</b>Para leer información de configuraciones de integraciones</li>
  #   <li><b>write_integration_config</b>Para manulupar o eliminar configuraciones de integraciones</li>
  #   <li><b>read_user</b>Para leer información de usuarios de la empresa</li>
  #   <li><b>write_user</b>Para manulupar o eliminar usuarios de la empresa</li>
  #   <li><b>read_webhook</b>Para leer información de webhooks</li>
  #   <li><b>write_webhook</b>Para manulupar o eliminar webhooks</li>
  # </ul>
  def authorization_url(scope)
    params = {
      "client_id" => @client_id,
      "redirect_uri" => @redirect_uri,
      "response_type" => "code",
      "scope" => scope
    }
    return "https://www.centry.cl/oauth/authorize?#{URI.encode_www_form(params)}"
  end

  ##
  # Método encargado de hacer todo tipo de solicitudes a Centry, desde autorizaciones hasta manipulación de inventario.
  # @var endpoint
  # @var method String indicado el método HTTP a usar. Las opciones son "GET", "POST", "PUT", "DELETE". Como es una API REST,
  #             estos métodos suelen estar asociados a la lectura, creación, edición y eliminacion de recursos.
  # @var params (opcional) Parámetros
  # @var payload (opcional) Body del request puede ser un objeto PHP o un arreglo (diccionario), internamente es transformado a JSON.
  def request(endpoint, method, params = {}, payload = {})
    query = params ? URI.encode_www_form(params) : ""
    uri = URI("https://www.centry.cl/#{endpoint}?#{query}")
    # uri = URI("https://www.centry.cl/#{endpoint}?#{query}")
    header = {
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }
    # header["Authorization"] = "Bearer #{@access_token}" #if !PUBLIC_ENDPOINTS.include?(endpoint)
    req = case method
    when :get    then Net::HTTP::Get.new(uri, header)
    when :post   then Net::HTTP::Post.new(uri, header)
    when :put    then Net::HTTP::Put.new(uri, header)
    when :delete then Net::HTTP::Delete.new(uri, header)
    end
    req.add_field("Authorization", "Bearer #{@access_token}") #if !PUBLIC_ENDPOINTS.include?(endpoint)

    req.body = JSON.generate(payload) if payload && payload != {}
    return Net::HTTP.start(uri.hostname, uri.port, use_ssl: false) do |http|
      http.request(req)
    end
  end

  ##
  # Una vez que un usuario ha autorizado nuestra aplicación para que accceda a su información, Centry genera un código
  # de autorización con el cual podremos solicitar el primer access_token y refresh_token. Éste método se encarga de
  # esta tarea por lo que se le debe entrecar el código de autorización como parámetro.
  # Se recomienda registrar estos tokens con algún mecanismo de persistencia como una base de datos.
  # @var code Código de autorización generado por Centry depués de que el usuario autorizó la aplicación.
  # @see https://www.oauth.com/oauth2-servers/access-tokens/authorization-code-request/
  def authorize(code)
    grant("authorization_code", {code: code})
  end

  ##
  # Un access_token tiene una vigencia de 7200 segudos (2 horas) por lo que una vez cumplido ese plazo es necesario
  # solicitar un nuevo token usando como llave el refresh_token que teníamos registrado. Este método se encarga de hacer
  # esta renovacion de tokens.
  # Se recomienda registrar estos nuevos tokens con algún mecanismo de persistencia como una base de datos.
  # @see https://www.oauth.com/oauth2-servers/access-tokens/authorization-code-request/
  def refresh
    grant("refresh_token", {refresh_token: @refresh_token})
  end

  def client_credentials
    grant("client_credentials")
  end

  private
  def grant(grant_type, extras = {})
    endpoint = "oauth/token"
    method = :post
    params = nil
    payload = {
      client_id: @client_id,
      client_secret: @client_secret,
      redirect_uri: @redirect_uri,
      grant_type: grant_type
    }.merge(extras)

    response = JSON.parse request(endpoint, method, params, payload).body

    @access_token = response["access_token"]
    @refresh_token = response["refresh_token"]
    @tokenType = response["token_type"]
    @scope = response["scope"]
    @createdAt = response["created_at"]
    @expiresIn = response["expires_in"]
  end

end
