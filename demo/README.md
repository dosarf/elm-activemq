
# findfirstunique-elm
Sample SPA webapp

- example for Elm itself
- example config webpack + elm-webpack-loader
- example usage material-components (multiple tabs)
- one tab (app) is standard Elm increase/decrease
- other is finding first unique item in a list of strings

## Building distribution

Install
- node and npm
- Elm 0.19
- elm-test (with npm)
- `npm install`
- (maybe) `elm make src/Main.elm --output temp.html`
	- to get Elm packages pulled in, CHECK: is this necessary?
- `npm run build`
- built app distribution is under `dist/`

## Running

Unfortunately, the Elm APP, if loaded from file system, is not able to interact
with ActiveMQ service, due to stuff like
- https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS/Errors/CORSDidNotSucceed .

Running ActiveMQ service on localhost does not help either.

So, to circumvent the problem, a little hack is employed: `local-proxy.js`.

### Starting `local-proxy.js`

- Install `node-http-server`: `npm install node-http-server`
- Configure the port `local-proxy.js` should listen to, if 8080 is not suitable
- Configure ActiveMQ forward host in `local-proxy-configuration-json`
  - in case of ActiveMQ's web service are not running on 8161,
		the forward port too
- Run `node local-proxy.js`

Once `local-proxy.js` is running, point your browser at where `local-proxy`
is running:
- the Elm app should load
- and ActiveMQ message publishing should also work.

## Testing Elm stuff

Run `elm test`
