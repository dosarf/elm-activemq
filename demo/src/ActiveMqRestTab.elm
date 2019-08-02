module ActiveMqRestTab exposing (
    Model, Msg, init, update, view
    , Person, personToJsonObject)

import Css exposing (px, width)
import Html.Styled exposing (Html, div)
import Html.Styled.Attributes exposing (css)
import Mwc.Button
import Mwc.TextField
import ActiveMq as AMQ
import Json.Encode as E
import Json.Decode as D
import Http

configuration : AMQ.Configuration
configuration =
    AMQ.configuration
        { host = AMQ.Host "localhost"
        , port_ = AMQ.Port 8080
        , credentials = AMQ.Credentials ("admin", "admin")
        , destination = AMQ.Queue "elm.queue"
        }

type alias Person =
    { name : String
    , age : Maybe Int
    }

personToJsonObject : Person -> E.Value
personToJsonObject person =
    E.object
        [ ("name", E.string person.name)
        , ("age", Maybe.map E.int person.age |> Maybe.withDefault E.null )
        ]

publishRequest : Model -> Cmd Msg
publishRequest model =
    let
        person =
            Person model.name model.age
        body =
            Http.jsonBody <| personToJsonObject person
    in
        AMQ.publishRequest configuration PersonPublicationResult body

personDecoder : D.Decoder Person
personDecoder =
    D.map2 Person (D.field "name" D.string) (D.maybe (D.field "age" D.int))

jsonStringToPerson : String -> Result String Person
jsonStringToPerson string =
    D.decodeString personDecoder string
        |> Result.mapError D.errorToString

consumeRequest : Model -> Cmd Msg
consumeRequest model =
    AMQ.consumeRequest configuration PersonConsumptionResult jsonStringToPerson

type alias Model =
    { name : String
    , age : Maybe Int
    , publishing : Bool
    , consuming : Bool
    , publicationResult : Maybe (Result Http.Error AMQ.PublicationResult)
    , consumptionResult : Maybe (Result AMQ.ConsumptionError Person)
    }


init : Model
init =
    { name = "John"
    , age = Just 42
    , publishing = False
    , consuming = False
    , publicationResult = Nothing
    , consumptionResult = Nothing
    }


type Msg
    = NameEdited String
    | AgeEdited String
    | PublishPersonToActiveMq
    | PersonPublicationResult (Result Http.Error AMQ.PublicationResult)
    | ConsumePersonFromActiveMq
    | PersonConsumptionResult (Result AMQ.ConsumptionError Person)


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        NameEdited name ->
            ( { model
              | name = name
              }
            , Cmd.none
            )

        AgeEdited text ->
            case text of
                "" ->
                  ( { model
                    | age = Nothing
                    }
                  , Cmd.none
                  )

                _ ->
                    let
                        newAge = String.toInt text
                    in
                        case newAge of
                            Nothing ->
                                ( model
                                , Cmd.none
                                )
                            _ ->
                                ( { model
                                  | age = newAge
                                  }
                                , Cmd.none
                                )

        PublishPersonToActiveMq ->
            ( { model
                | publishing = True
                , publicationResult = Nothing
              }
            , publishRequest model
            )

        PersonPublicationResult result ->
            let
                _ = Debug.log "publication result" result
            in
                ( { model
                    | publishing = False
                    , publicationResult = Just result
                  }
                , Cmd.none
                )

        ConsumePersonFromActiveMq ->
            ( { model
              | consuming = True
              , consumptionResult = Nothing
              }
            , consumeRequest model
            )

        PersonConsumptionResult result ->
            let
                _ = Debug.log "consumption result" result
            in
                ( { model
                  | consuming = False
                  , consumptionResult = Just result
                  }
                , Cmd.none
                )


personPublishDataView : Model -> Html Msg
personPublishDataView model =
    div
        []
        [ Mwc.TextField.view
            [ Mwc.TextField.inputType "text"
            , Mwc.TextField.value model.name
            , Mwc.TextField.onInput NameEdited
            , Mwc.TextField.placeHolder "(name)"
            ]
        , Mwc.TextField.view
            [ Mwc.TextField.inputType "number"
            , Mwc.TextField.value (Maybe.map String.fromInt model.age |> Maybe.withDefault "")
            , Mwc.TextField.onInput AgeEdited
            , Mwc.TextField.placeHolder "(age)"
            ]
        ]

personPublishButton : Model -> Html Msg
personPublishButton model =
    Mwc.Button.view
        [ Mwc.Button.raised
        , Mwc.Button.disabled model.publishing
        , Mwc.Button.onClick PublishPersonToActiveMq
        , Mwc.Button.label "Publish"
        ]

httpErrorToString : Http.Error -> String
httpErrorToString httpError =
    case httpError of
        Http.BadUrl string ->
            "Bad URL: " ++ string

        Http.Timeout ->
            "Timeout"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus int ->
            "Bad status: " ++ (String.fromInt int)

        Http.BadBody string ->
            "Bad body: " ++ string

consumptionErrorToString : AMQ.ConsumptionError -> String
consumptionErrorToString consumptionError =
    case consumptionError of
        AMQ.BadUrl string ->
            "Bad URL: " ++ string

        AMQ.Timeout ->
            "Timeout"

        AMQ.NetworkError ->
            "Network error"

        AMQ.BadStatus int ->
            "Bad status: " ++ (String.fromInt int)

        AMQ.BadBody string ->
            "Bad body: " ++ string

        AMQ.NoMessage ->
            "No message to consume"


publicationResultText : Result Http.Error AMQ.PublicationResult -> String
publicationResultText result =
    case result of
        Ok _ ->
            "Message sent"
        Err error ->
            httpErrorToString error

personPublicationResultView : Model -> Html msg
personPublicationResultView model =
    let
        resultString =
            model.publicationResult
                |> Maybe.map publicationResultText
                |> Maybe.withDefault "(nothing sent yet)"
    in
        div
            []
            [ Mwc.TextField.view
                [ Mwc.TextField.value resultString
                , Mwc.TextField.readonly True
                , Mwc.TextField.noOp
                , Mwc.TextField.textArea
                ]
            ]

personConsumeButton : Model -> Html Msg
personConsumeButton model =
    Mwc.Button.view
        [ Mwc.Button.raised
        , Mwc.Button.disabled model.consuming
        , Mwc.Button.onClick ConsumePersonFromActiveMq
        , Mwc.Button.label "Consume"
        ]

personConsumptionView : Model -> Html Msg
personConsumptionView model =
    case model.consumptionResult of
        Nothing ->
            Mwc.TextField.view
                [ Mwc.TextField.value "(nothing consumed yet)"
                , Mwc.TextField.readonly True
                , Mwc.TextField.noOp
                , Mwc.TextField.textArea
                ]
        Just consumptionResult ->
            case consumptionResult of
                Err consumptionError ->
                    Mwc.TextField.view
                        [ Mwc.TextField.value <| consumptionErrorToString consumptionError
                        , Mwc.TextField.readonly True
                        , Mwc.TextField.noOp
                        , Mwc.TextField.textArea
                        ]
                Ok person ->
                    div
                        []
                        [ Mwc.TextField.view
                            [ Mwc.TextField.inputType "text"
                            , Mwc.TextField.value person.name
                            , Mwc.TextField.readonly True
                            , Mwc.TextField.noOp
                            ]
                        , Mwc.TextField.view
                            [ Mwc.TextField.inputType "text"
                            , Mwc.TextField.value (Maybe.map String.fromInt person.age |> Maybe.withDefault "(undefined)")
                            , Mwc.TextField.readonly True
                            , Mwc.TextField.noOp
                            ]
                        ]



view : Model -> Html Msg
view model =
    div
        [ css [ width (px 300) ] ]
        [ personPublishDataView model
        , personPublishButton model
        , personPublicationResultView model
        , personConsumeButton model
        , personConsumptionView model
        ]
