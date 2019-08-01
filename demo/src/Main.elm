module Main exposing (main)

import Browser
import Css exposing (Color, backgroundColor, border3, display, height, hex, inlineBlock, padding, px, rgb, solid, width)
import Html.Styled exposing (Html, div, header, img, main_, map, text, toUnstyled)
import Html.Styled.Attributes exposing (css, src)
import ActiveMqRestTab
import Mwc.Button
import Mwc.Tabs
import Mwc.TextField


type alias Model =
    { currentTab : Int
    , activeMqRestModel : ActiveMqRestTab.Model
    }


init : () -> (Model, Cmd Msg)
init () =
    ( { currentTab = 0
      , activeMqRestModel = ActiveMqRestTab.init
      }
    , Cmd.none
    )


type Msg
    = SelectTab Int
    | ActiveMqRestMsg ActiveMqRestTab.Msg


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        SelectTab newTab ->
            ( { model
              | currentTab = newTab
              }
            , Cmd.none
            )

        ActiveMqRestMsg activeMqRestMsg ->
            let
                (activeMqRestModel, cmd) = ActiveMqRestTab.update activeMqRestMsg model.activeMqRestModel
            in
                ( { model
                  | activeMqRestModel = activeMqRestModel
                  }
                , Cmd.map ActiveMqRestMsg cmd
                )


{-| A logo image, with inline styles that change on hover.
-}
logo : Html msg
logo =
    img
        [ src "assets/activemq_logo_white_vertical.png"
        , css
            [ display inlineBlock
            , height (px 167)
            , width (px 204)
            , padding (px 20)
            , border3 (px 5) solid (rgb 120 120 120)
            ]
        ]
        []


view : Model -> Html Msg
view model =
    main_ []
        [ header
            [ css
                [ backgroundColor (hex "78932c")
                ]
            ]
            [ div
                []
                [ logo ]
            ]
        , div
            [ css [ width (px 400) ] ]
            [ Mwc.Tabs.view
                [ Mwc.Tabs.selected model.currentTab
                , Mwc.Tabs.onClick SelectTab
                , Mwc.Tabs.tabText
                    [ text "ActiveMQ REST"
                    ]
                ]
            , tabContentView model
            ]
        ]


tabContentView : Model -> Html Msg
tabContentView model =
    case model.currentTab of
        _ ->
            map ActiveMqRestMsg (ActiveMqRestTab.view model.activeMqRestModel)


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none

main =
    Browser.element
        { init = init
        , view = view >> toUnstyled
        , update = update
        , subscriptions = subscriptions
        }
