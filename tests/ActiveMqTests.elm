module ActiveMqTests exposing (testSuite)

import Expect
import Test exposing (..)
import ActiveMq exposing (..)

queueConfiguration : Configuration
queueConfiguration =
    configuration
        { host = Host "example.com"
        , port_ = defaultPort
        , credentials = Credentials ("admin", "admin")
        , destination = Queue "hello.queue"
        }

testSuite =
    describe "ActiveMq tests"
        [ test "configuration has correctly constructed URL for queue" <|
            \() ->
                "http://example.com:8161/api/message/TEST?type=queue&destination=queue://hello.queue"
                    |> Expect.equal (urlOf queueConfiguration)

        ]
