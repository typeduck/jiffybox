###############################################################################
# Lists Server information
###############################################################################

Promise = require("bluebird")
JiffyBoxClient = require("../src/JiffyBoxClient")
CONFIG = require("convig").env({
  APIKEY: () -> throw new Error("set env var APIKEY for tests!")
})

Promise.try(() ->
  client = new JiffyBoxClient(CONFIG.APIKEY)
  client.getJiffyBoxes()
)
.then((data) ->
  data.forEach (box) -> console.log(box)
)
.catch((e) ->
  console.error(e)
)
