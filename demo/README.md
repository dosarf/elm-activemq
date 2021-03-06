
# ActiveMQ demo

- example for `dosarf/elm-activemq`
- as well as for `dosarf/elm-yet-another-polling`

## Pre-requisites

Obviously you need an ActiveMQ installation:
[download](https://activemq.apache.org/) it, unzip it and start its service.

## Building distribution

Install
- node and npm
- Elm 0.19
- elm-test (with npm)
- `npm install`
- `npm run build`
- built app distribution is under `dist/`

## Cross-Origin Resource Sharing

You need to set up your ActiveMQ for
[Cross-Origin Resource Sharing (CORS)](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
correctly.

That's a bit of a bother, so in order to run this demo quickly, you could use
the Node JS script `local-proxy.js` right here in the root of this demo app
project folder.

It requires Node module `node-http-server`, after installing that, you can just do

```> node local-proxy.js
```

Point your browser to localhost:8080, this little script will serve both the
static files of this demo app as well as act as a reverse proxy to your
ActiveMQ service.
* In case you are not running ActiveMQ locally, or on a port different to the
	default ones, configure `local-proxy-configuration.json`.

## Running the demo app

Having `local-proxy.js` started, this demo app should be able to both load
and publish / consume from ActiveMQ service. The demo queue used is `elm.queue`.
