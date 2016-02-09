###############################################################################
# Tests for JiffyBox Client Library
###############################################################################

should = require("should")
Promise = require("bluebird")
Moment = require("moment")

jiffybox = require("./JiffyBoxClient")
CONFIG = require("convig").env({
  APIKEY: () -> throw new Error("set env var APIKEY for tests!")
})

describe "JiffBoxClient", () ->

  client = null
  before () -> client = jiffybox(CONFIG.APIKEY)
  genpass = () ->
    lower = "abcdefghijklmnopqrstuvwxyz".split("")
    upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("")
    numbers = "0123456789".split("")
    special = "!@#$%^&*()_-".split("")
    pick = (a, num) ->
      s = []
      i = 0
      while i++ < num
        s.push( a[Math.floor(Math.random() * a.length)] )
      return s
    p = pick(lower, 4)
    p = p.concat(pick(upper, 4))
    p = p.concat(pick(numbers, 3))
    p = p.concat(pick(special, 3))
    return p.join("")

  distros = null
  plans = null

  it "should be able to access Distros", () ->
    @timeout(10000)
    Promise.try(() -> client.getDistros() )
    .then((data) -> distros = data)

  it "should be able to access Plans", () ->
    @timeout(10000)
    Promise.try(() -> client.getPlans())
    .then((data) -> plans = data)

  it "should create, wait for READY, and delete a JiffyBox", () ->
    @timeout(600000)
    Promise.bind({}).then(() ->
      params =
        name: "auto-" + Moment().format("YYYY-MM-DD[T]HH.mm.ss")
        planid: cheapestPlanId(plans)
        distribution: someDebian(distros)
        password: genpass()
        metadata:
          purpose: "testing"
          created: new Date()
      client.createJiffyBox(params)
    )
    .then((@box) ->
      isReady = (box) -> box.running and box.status is "READY"
      client.waitForStatus(@box.id, isReady)
    )
    .then(() ->
      canShutdown = (box) -> box.status is "READY" and not box.running
      client.setStatusAndWait(@box.id, "SHUTDOWN", canShutdown)
    )
    .then(() ->
      client.deleteJiffyBox(@box.id)
    )

# finds the cheapest plan from the list
cheapestPlanId = (plans) ->
  plans.sort (a, b) -> 100 * (a.pricePerHour - b.pricePerHour)
  plans[0].id
# Finds some flavour of Debian to install
someDebian = (distros) ->
  for distro in distros when (/debian/i).test(distro.name)
    return distro.key
