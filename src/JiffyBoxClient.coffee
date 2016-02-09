###############################################################################
# Implementation of the JiffyBox API, wraps request with defaults, and adds
# rate-limiting.
###############################################################################

Promise = require("bluebird")
Request = require("request")
RateLimiter = require("limiter").RateLimiter

module.exports = (apikey) -> new JiffyBoxClient(apikey)

class JiffyBoxClient
  constructor: (@apiKey, limit = 2500) ->
    @limiter = Promise.promisifyAll(new RateLimiter(1, limit))
    @requester = Promise.promisifyAll(Request.defaults({
      json: true
      baseUrl: "https://api.jiffybox.de/#{@apiKey}/v1.0/"
      method: "GET"
    }))

  # makes HTTP Request to API
  doRequest: (path, args...) ->
    Promise.bind({self: @}).then(() ->
      @opts = { uri: path, method: "GET", timeout: 10000 }
      @toArray = false
      # Overwrite defaults
      while (arg = args.shift())
        switch (argType = typeof arg)
          when "string" then @opts.method = arg.toUpperCase()
          when "object" then @opts.body = arg
          when "boolean" then @toArray = arg
      @self.limiter.removeTokensAsync(1)
    )
    .then(() ->
      reqMethod = @opts.method || "GET"
      if reqMethod is "DELETE" then reqMethod = "DEL"
      reqMethod = reqMethod.toLowerCase() + "Async"
      @self.requester[reqMethod](@opts)
    )
    .then((res) ->
      body = res.body
      if result = body?.result
        return if @toArray then toArray(result) else result
      if body.messages?.length
        errmsg = ""
        for msg in body.messages
          errmsg += "(#{msg.type}) #{msg.message}\n"
        throw new Error(errmsg)
      throw new Error("Unknown JiffyBoxClient Error")
    )

  # API Detailed Implementation
  getDistros: () ->
    @doRequest("distributions", true)
  getPlans: () ->
    @doRequest("plans", true)

  # JiffyBox Management: Get all the JiffyBoxes
  getJiffyBoxes: () ->
    @doRequest("jiffyBoxes", true)
  # Single JiffyBox Management
  createJiffyBox: (params) ->
    @doRequest("jiffyBoxes", "POST", params)
  getJiffyBox: (id) ->
    @doRequest("jiffyBoxes/#{id}")
  deleteJiffyBox: (id) ->
    @doRequest("jiffyBoxes/#{id}", "DELETE")
  # Polls the JiffyBox for a particular stats (e.g. READY)
  waitForStatus: (id, checkStatus) ->
    if typeof checkStatus is "string"
      statusNeeded = checkStatus
      checkStatus = (box) -> box.status is statusNeeded
    @getJiffyBox(id).then((box) =>
      return box if checkStatus(box)
      Promise.delay(5000).then(() =>
        @waitForStatus(id, checkStatus)
      )
    )
  setStatus: (id, statusWanted) ->
    @doRequest("jiffyBoxes/#{id}", "PUT", {status: statusWanted})
  setStatusAndWait: (id, statusWanted, checkStatus) ->
    @setStatus(id, statusWanted).then(() =>
      @waitForStatus(id, checkStatus)
    )
  # List of available Backups
  getBackups: () ->
    @doRequest("backups", true)

# Converts a hash into an array of values, putting the key as a property on each
# object.
toArray = (obj, keyName = "key") ->
  out = []
  for k, v of obj
    out.push(v)
    v[keyName] = k
  return out
