module ActiveMq exposing (
      ConfigParams
    , Configuration
    , configuration
    , Credentials (..)
    , defaultPort
    , Destination (..)
    , Host (..)
    , Port (..)
    , publishRequest, PublicationResult (..)
    , consumeRequest, consumeRequestTask, ConsumptionError (..)
    , urlOf, authenticationOf)

{-| A package for very simplistic interaction with ActiveMQ REST API.

## Configuration

@docs ConfigParams, Configuration, configuration, Credentials, defaultPort, Destination, Host, Port

## Publishing

@docs PublicationResult, publishRequest

## Consuming

@docs consumeRequest, consumeRequestTask, ConsumptionError

## Misc

@docs urlOf, authenticationOf
-}

import Base64 as B64
import Http
import Task

{-| Host of the ActiveMQ service.
-}
type Host =
    Host String

{-| TCP Port of the ActiveMQ REST API service, see [`defaultPort`](#defaultPort).
-}
type Port =
    Port Int

{-| Default TCP port of the REST API of ActiveMQ installations, 8161.
-}
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

{-| A record carrying parameters for constructing a [`Configuration`](#Configuration).
-}
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

{-| A configuration needed to publish / consume, see [`configuration`](#configuration).
-}
type Configuration =
    Configuration ConfigurationData

{-| Constructs a [`Configuration`](#Configuration) based in config params.
-}
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

{-| The URL of a [`Configuration`](#Configuration)
to be used by publish/consume requests.
-}
urlOf : Configuration -> String
urlOf configuration_ =
    case configuration_ of
        Configuration { url, authentication } ->
            url

{-| The authentication details of a [`Configuration`](#Configuration)
to be used by publish/consume requests.
-}
authenticationOf : Configuration -> String
authenticationOf configuration_ =
    case configuration_ of
        Configuration { url, authentication } ->
            authentication

{-| The result of a publication attempt (can only convey success for now).
-}
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
* a configuration,
* a `createMessage` function turning the result of a publication into a
  message of your choice,
* an HTTP body you want to publish,

it constructs a POST request that will try to publish to ActiveMQ to configured
destination.
-}
publishRequest : Configuration -> (Result Http.Error PublicationResult -> msg) -> Http.Body -> Cmd msg
publishRequest configuration_ createMessage body =
    Http.request
        { method = "POST"
        , headers =
            [ Http.header "Authorization" <| authenticationOf configuration_
            ]
        , url = urlOf configuration_
        , body = body
        , expect = Http.expectString (expectMessageSent >> createMessage)
        , timeout = Nothing
        , tracker = Nothing
        }

{-| Most similar to `Http.Error`, except there is a specific case for not having
any message to be consumed within the timeframe the call lasted (`HTTP 204 No Content`).
-}
type ConsumptionError =
    BadUrl String
    | Timeout
    | NetworkError
    | BadStatus Int
    | BadBody String
    | NoMessage

parseConsumptionResponse : (String -> Result String value) -> (Http.Response String -> Result ConsumptionError value)
parseConsumptionResponse parseBody =
    \response ->
        case response of
            Http.BadUrl_ url ->
                Err (BadUrl url)

            Http.Timeout_ ->
                Err Timeout

            Http.NetworkError_ ->
                Err NetworkError

            Http.BadStatus_ metadata body ->
                Err (BadStatus metadata.statusCode)

            Http.GoodStatus_ metadata body ->
                if metadata.statusCode == 204 then
                    Err NoMessage

                else
                    case parseBody body of
                        Ok value ->
                            Ok value

                        Err err ->
                            Err (BadBody err)


{-| Given
* a configuration
* a `createMessage` function turning the result of a publication into a
  message of your choice,
* a parser turning a response body into a result,

it constructs an HTTP GET request that will consume a message from configured
destination. Success/failure responses will lead to a message of
the type of your choice.

You cannot cancel this request right now, and it looks you should not, either:
the little one-shot JMS consumer created for your request will be there, in
the context of the REST API servlet within ActiveMQ service, for
30 seconds by default, even if you cancel the HTTP request ("servlet timeout").
That means certain loss of any message published between instant of canceling the
HTTP request and that JMS consumer is being destroyed.

Do _not_ use this call directly to organize a polling loop, since network failures
and such will result in very busy polling indeed.
-}
consumeRequest : Configuration -> (Result ConsumptionError value -> msg) -> (String -> Result String value) -> Cmd msg
consumeRequest configuration_ createMessage parseBody =
    Http.request
        { method = "GET"
        , headers =
            [ Http.header "Authorization" <| authenticationOf configuration_
            ]
        , url = (urlOf configuration_) ++ "&oneShot=true"
        , body = Http.emptyBody
        , expect = Http.expectStringResponse createMessage (parseConsumptionResponse parseBody)
        , timeout = Nothing
        , tracker = Nothing
        }

{-| Creates a task instead of a command, but otherwise similar to [`consumeRequest`](#consumeRequest).

You may want to use this version to implement correct message pollling loop with back-off
strategy etc.
-}
consumeRequestTask : Configuration -> (String -> Result String value) -> Task.Task ConsumptionError value
consumeRequestTask configuration_ parseBody =
    Http.task
        { method = "GET"
        , headers =
            [ Http.header "Authorization" <| authenticationOf configuration_
            ]
        , url = (urlOf configuration_) ++ "&oneShot=true"
        , body = Http.emptyBody
        , resolver = Http.stringResolver (parseConsumptionResponse parseBody)
        , timeout = Nothing
        }


basicAuthentication : Credentials -> String
basicAuthentication credentials =
    case credentials of
        Credentials (user, password) ->
            B64.encode <| user ++ ":" ++ password
