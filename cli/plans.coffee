###############################################################################
# Lists Plan information
###############################################################################

JiffyBoxClient = require("../src/JiffyBoxClient")
CONFIG = require("convig").env({
  APIKEY: () -> throw new Error("set env var APIKEY for tests!")
})

client = new JiffyBoxClient(CONFIG.APIKEY)
client.getPlans (err, plans) ->
  plans.forEach (plan) ->
    console.log(plan)
