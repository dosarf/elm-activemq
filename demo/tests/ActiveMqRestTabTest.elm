module ActiveMqRestTabTest exposing (testSuite)

import Expect
import Test exposing (..)
import ActiveMqRestTab exposing (..)
import Json.Encode as E

personToJsonString : Person -> String
personToJsonString person =
    personToJsonObject person |> E.encode 0

testSuite =
    describe "ActiveMqRestTab"
        [ test "Practice for JSON encoding a fully defined person" <|
              \() ->
                  """{"name":"John","age":42}"""
                      |> Expect.equal (personToJsonString <| Person "John" (Just 42))
        , test "Practice for JSON encoding an ageless person" <|
              \() ->
                  """{"name":"John","age":null}"""
                      |> Expect.equal (personToJsonString <| Person "John" Nothing)
        ]
