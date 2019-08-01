module ActiveMq exposing (
      ConfigParams
    , Configuration
    , configuration
    , Credentials (..)
    , defaultPort
    , Destination (..)
    , Host (..)
    , Port (..)
    , PublicationResult (..)
    , publishRequest
    , urlOf, authenticationOf)

import Base64 as B64
import Http

type Host =
    Host String

type Port =
    Port Int

defaultPort : Port
defaultPort =
    Port 8161

type Credentials =
    Credentials (String, String)

type Destination =
    Queue String
    | Topic String

type alias ConfigParams =
    { host : Host
    , port_ : Port
    , credentials : Credentials
    , destination : Destination
    }

type alias ConfigurationData =
    { url: String
    , authentication : String
    }

type Configuration =
    Configuration ConfigurationData

configuration : ConfigParams -> Configuration
configuration configParams =
    let
        host =
            case configParams.host of
                Host host2 ->
                    host2
        port_ : String
        port_ =
            case configParams.port_ of
                Port port_2 ->
                    String.fromInt port_2
        destinationUrlParams =
            case configParams.destination of
                Queue queue ->
                    "?type=queue&destination=queue://" ++ queue
                Topic topic ->
                    "?type=topic&destination=topic://" ++ topic
        authorizationHeaderValue =
            case configParams.credentials of
                credentials ->
                    "Basic " ++ (basicAuthentication credentials)
    in
        Configuration
            { url =
                "http://"
                ++ host
                ++ ":" ++ port_
                ++ "/api/message/TEST"
                ++ destinationUrlParams
            , authentication =
                authorizationHeaderValue
            }

urlOf : Configuration -> String
urlOf configuration_ =
    case configuration_ of
        Configuration { url, authentication } ->
            url

authenticationOf : Configuration -> String
authenticationOf configuration_ =
    case configuration_ of
        Configuration { url, authentication } ->
            authentication

type PublicationResult =
    Success

expectMessageSent : Result Http.Error String -> Result Http.Error PublicationResult
expectMessageSent result =
    case result of
        Err error ->
            Err error
        Ok "Message sent" ->
            Ok Success
        Ok badBody ->
            Err (Http.BadBody badBody)


publishRequest : Configuration -> (Result Http.Error PublicationResult -> msg) -> Http.Body -> Cmd msg
publishRequest configuration_ msgConstructor body =
    Http.request
        { method = "POST"
        , headers =
            [ Http.header "Authorization" <| authenticationOf configuration_
            -- , Http.header "Content-Type" "text/plain"
            -- , Http.header "Content-Length" <| String.length messageBody
            ]
        , url = urlOf configuration_
        , body = body
        , expect = Http.expectString (expectMessageSent >> msgConstructor)
        , timeout = Nothing
        , tracker = Nothing
        }

basicAuthentication : Credentials -> String
basicAuthentication credentials =
    case credentials of
        Credentials (user, password) ->
            B64.encode <| user ++ ":" ++ password
