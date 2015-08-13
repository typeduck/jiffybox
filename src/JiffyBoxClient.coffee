###############################################################################
# Implementation of the JiffyBox API, wraps request with defaults, and adds
# rate-limiting.
###############################################################################

Request = require("request")
async = require("async")
limiter = new (require("limiter")).RateLimiter(1, 2100)
EventEmitter = require("events").EventEmitter

module.exports = class JiffyBoxClient extends EventEmitter
  constructor: (@apiKey) ->
    request = Request.defaults({
      json: true
      baseUrl: "https://api.jiffybox.de/#{@apiKey}/v1.0/"
      method: "GET"
    })
    explain = (msg) -> "(#{msg.type}) #{msg.message}"
    handleRequest = (task, done) =>
      limiter.removeTokens 1, () =>
        request task.opts, (err, res, body) =>
          done() # call for async.queue
          if body.messages.length
            @emit("messages", body.messages, task.opts)
          if body.result
            @emit("result", body.result, task.opts)
          return if typeof task.done isnt "function"
          return task.done(err) if err
          if result = body?.result
            if task.toArray then result = toArray(result)
            task.done(null, result)
          else if messages = body?.messages
            errmsg = messages.map(explain).join("\n")
            task.done(new Error(errmsg))
          else
            task.done(new Error("Unknown JiffyBoxClient Error"))
    @queue = async.queue(handleRequest, 1)

  # performs a request according to the global limit
  doRequest: (path, args...) ->
    opts = { uri: path, method: "GET" }
    task = { opts: opts, toArray: false }
    # Overwrite defaults
    while (arg = args.shift())
      switch (argType = typeof arg)
        when "string" then opts.method = arg.toUpperCase()
        when "object" then opts.body = arg
        when "function" then task.done = arg
        when "boolean" then task.toArray = arg
    @queue.push(task)

  # API Detailed Implementation
  getDistros: (done, asArray = true) ->
    @doRequest("distributions", asArray, done)
  getPlans: (done, asArray = true) ->
    @doRequest("plans", asArray, done)

  # JiffyBox Management: Get all the JiffyBoxes
  getJiffyBoxes: (done, asArray = true) ->
    @doRequest("jiffyBoxes", asArray, done)
  # Single JiffyBox Management
  createJiffyBox: (params, done) ->
    @doRequest("jiffyBoxes", "POST", params, done)
  getJiffyBox: (id, done) ->
    @doRequest("jiffyBoxes/#{id}", done)
  deleteJiffyBox: (id, done) ->
    @doRequest("jiffyBoxes/#{id}", "DELETE", done)
  # Polls the JiffyBox for a particular stats (e.g. READY)
  waitForStatus: (id, checkStatus, done) ->
    if typeof checkStatus is "string"
      statusNeeded = checkStatus
      checkStatus = (box) -> box.status is statusNeeded
    @getJiffyBox id, (err, box) =>
      return done(err, box) if err
      return done(null, box) if checkStatus(box)
      waitAgain = () => @waitForStatus(id, checkStatus, done)
      setTimeout(waitAgain, 5000)
  setStatus: (id, statusWanted, done) ->
    @doRequest("jiffyBoxes/#{id}", "PUT", {status: statusWanted}, done)
  setStatusAndWait: (id, statusWanted, checkStatus, done) ->
    @setStatus id, statusWanted, (err) =>
      if err then done(err) else @waitForStatus(id, checkStatus, done)

# Converts a hash into an array of values, putting the key as a property on each
# object.
toArray = (obj, keyName = "key") ->
  out = []
  for k, v of obj
    out.push(v)
    v[keyName] = k
  return out
