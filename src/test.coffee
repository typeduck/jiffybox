###############################################################################
# Tests for JiffyBox Client Library
###############################################################################

should = require("should")
async = require("async")
Moment = require("moment")

JiffyBoxClient = require("./JiffyBoxClient")
CONFIG = require("convig").env({
  APIKEY: () -> throw new Error("set env var APIKEY for tests!")
})

describe "JiffBoxClient", () ->

  client = null
  before () ->
    client = new JiffyBoxClient(CONFIG.APIKEY)
    client.on "messages", (messages, opts) ->
      console.error("Messages from %s '%s'", opts.method, opts.uri)
      for message in messages
        console.error("(%s) %s", message.type, message.message)
    client.on "result", (result, opts) ->
      console.error("Result from %s '%s'", opts.method, opts.uri)
      console.error( JSON.stringify(result) )

  it "should create, wait for READY, and delete a JiffyBox", (done) ->
    @timeout(600000)
    async.auto {
      password: (next, auto) ->
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
        next(null, p.join(""))
      box: ["password", "distros", "plans", (next, auto) ->
        params =
          name: "auto-" + Moment().format("YYYY-MM-DD[T]HH.mm.ss")
          planid: cheapestPlanId(auto.plans)
          distribution: someDebian(auto.distros)
          password: auto.password
          metadata:
            purpose: "testing"
            created: new Date()
        client.createJiffyBox(params, next)
      ]
      ready: ["box", (next, auto) ->
        isReady = (box) -> box.running and box.status is "READY"
        client.waitForStatus(auto.box.id, isReady, next)
      ]
      shutdown: ["box", "ready", (next, auto) ->
        canShutdown = (box) -> box.status is "READY" and not box.running
        client.setStatusAndWait(auto.box.id, "SHUTDOWN", canShutdown, next)
      ]
      remove: ["box", "shutdown", (next, auto) ->
        client.deleteJiffyBox(auto.box.id, next)
      ]
      distros: (next) ->
        client.getDistros (err, data) -> next(err, data)
      plans: (next) ->
        client.getPlans (err, data) -> next(err, data)
    }, done

# finds the cheapest plan from the list
cheapestPlanId = (plans) ->
  plans.sort (a, b) -> 100 * (a.pricePerHour - b.pricePerHour)
  plans[0].id
# Finds some flavour of Debian to install
someDebian = (distros) ->
  for distro in distros when (/debian/i).test(distro.name)
    return distro.key
