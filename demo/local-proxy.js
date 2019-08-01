'use strict';

/* Based on
  http://riaevangelist.github.io/node-http-server/README.md.html
  - https://github.com/RIAEvangelist/node-http-server/blob/master/example/basic/basicApp.js
  - https://github.com/RIAEvangelist/node-http-server/blob/master/example/proxy/https-and-http-google-proxy.js

  Running
  - npm install node-http-server
  - create configuration json file, next to this script, local-proxy-configuration.json
    e.g.

    {
      "port": 8080,
      "rules": [
          {
            "target" : "ActiveMQ",
            "test" : "/api/message/",
            "forward" : {
              "host" : "localhost",
              "port" : 8161
            }
          }
      ]
    }

    port is where the local-proxy will listen to.

    rules is an array of simple URL testing rules and where to forward to.
    HTTP method, URI path, request headers and body are preserved, host:port
    are taken from the rule.

    The first matching rule is applied.

    If none matches, ordinary response lifecycle continues (files).

  - node local-proxy.js (works with node 8.10.0).
*/

const server = require('node-http-server');
const proxy = require('request');

const proxyConfig = require('./local-proxy-configuration.json');

console.log(proxyConfig);

//checkout the server in the console
console.log(server);

server.onRequest=gotRequest;

//start the server with a config
server.deploy(
    {
        verbose : true,
        port : proxyConfig.port,
        root : __dirname + proxyConfig.relativeRoot
    }
);

function gotRequest(request,response,serve){

    let encoding = 'binary';

    var i;
    for (i = 0; i < proxyConfig.rules.length; i += 1) {
      var rule = proxyConfig.rules[i];

      if (request.url.startsWith(rule.test)) {
        console.log('Found a rule, forwarding to ' + rule.target);

        proxy(
            {
                url : `http://${rule.forward.host}:${rule.forward.port}${request.uri.path}`,
                method : request.method,
                headers: request.headers,
                encoding : encoding,
                body : request.body
            },
            function (error, proxiedResponse, proxiedBody) {
                if (error) {
                    request.statusCode=500;
                    serve (request, response, JSON.stringify(error) );
                    return;
                }

                response.headers = proxiedResponse.headers;
                response.statusCode = proxiedResponse.statusCode;

                serve(request, response, proxiedBody);

                return;
            }
        );

        // interrupt response lifecycle, we are serving proxied response manually
        return true;

      }
    }

    // proceed with normal response lifecycle (files and stuff)
    return false;
}
