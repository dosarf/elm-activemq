'use strict';

import img from './assets/activemq_logo_white_vertical.png'
require('./index.html');
var Elm = require('./Main.elm').Elm;

var app = Elm.Main.init({
  node: document.getElementById('main')
});
