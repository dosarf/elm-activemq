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
    , publishRequest, consumeRequest
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

{-| A tuple of user/password string pair.
-}
type Credentials =
    Credentials (String, String)

{-| JMS destinations are either queues or topics. Both type have a name.
-}
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

{-| Given
- a configuration,
- a message (constructor) taking `Result Http.Error PublicationResult`
- an HTTP body you want to publish

it constructs a POST request that will try to publish to ActiveMQ to configured
destination. Success/failure responses will lead to a message of
the type of your choice.
-}
publishRequest : Configuration -> (Result Http.Error PublicationResult -> msg) -> Http.Body -> Cmd msg
publishRequest configuration_ msgConstructor body =
    Http.request
        { method = "POST"
        , headers =
            [ Http.header "Authorization" <| authenticationOf configuration_
            ]
        , url = urlOf configuration_
        , body = body
        , expect = Http.expectString (expectMessageSent >> msgConstructor)
        , timeout = Nothing
        , tracker = Nothing
        }

parseConsumptionResponse : (String -> Result String value) -> (Http.Response String -> Result Http.Error value)
parseConsumptionResponse parseBody =
    \response ->
        case response of
            Http.BadUrl_ url ->
                Err (Http.BadUrl url)

            Http.Timeout_ ->
                Err Http.Timeout

            Http.NetworkError_ ->
                Err Http.NetworkError

            Http.BadStatus_ metadata body ->
                Err (Http.BadStatus metadata.statusCode)

            Http.GoodStatus_ metadata body ->
                case (metadata.statusCode, parseBody body) of
                    (204, _) -> -- TODO, avoid parsing if we already know there is no body to speak of
                        Err Http.Timeout

                    (_, Ok value) ->
                        Ok value

                    (_, Err err) ->
                        Err (Http.BadBody err)


{-| Given
- a configuration
- a message (constructor) taking `Result Http.Error some-value-of-yours`
- a parser turning a body into a `Result String some-value-of-yours`

you get an HTTP GET requet that will consume a message from configured
destination. Success/failure responses will lead to a message of
the type of your choice.

You cannot cancel this request right now, and it looks you should not, either:
the little one-shot JMS consumer created for your request will be there, in
the context of the REST API servlet within ActiveMQ service, for
(about) 30 seconds, even if you cancel the HTTP request ("servlet timeout").
That means certain loss of any message published between instant of canceling the
HTTP request and that JMS consumer is being destroyed.

TODO: This is not ready not be used in a loop with the purpose of implementing a
      manual message polling.
      - Message successfully consumed, network timeout and "servlet timeout" can
        be followed by an immediate HTTP request again,
      - but some other errors (e.g. networking error) should
        employ some configurable back-off policy,
      - and perhaps some other type of errors (bad URL, ...) should quit the
        loop entirely.

      The point is we don't want Elm apps to busy-poll (erroneously) ActiveMQ.
-}
consumeRequest : Configuration -> (Result Http.Error value -> msg) -> (String -> Result String value) -> Cmd msg
consumeRequest configuration_ msgConstructor parseBody =
    Http.request
        { method = "GET"
        , headers =
            [ Http.header "Authorization" <| authenticationOf configuration_
            ]
        , url = (urlOf configuration_) ++ "&oneShot=true"
        , body = Http.emptyBody
        , expect = Http.expectStringResponse msgConstructor (parseConsumptionResponse parseBody)
        , timeout = Nothing
        , tracker = Nothing
        }

basicAuthentication : Credentials -> String
basicAuthentication credentials =
    case credentials of
        Credentials (user, password) ->
            B64.encode <| user ++ ":" ++ password
