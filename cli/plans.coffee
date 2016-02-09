###############################################################################
# Lists Plan information
###############################################################################

Promise = require("bluebird")
JiffyBoxClient = require("../src/JiffyBoxClient")
CONFIG = require("convig").env({
  APIKEY: () -> throw new Error("set env var APIKEY for tests!")
})

Promise.try(() ->
  client = new JiffyBoxClient(CONFIG.APIKEY)
  client.getPlans()
)
.then((plans) ->
  plans.forEach (plan) -> console.log(plan)
)
.catch((e) ->
  console.error(e)
)
