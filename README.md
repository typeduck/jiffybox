# JiffyBox

Client library for managing domainFACTORY virtual servers via the
[JiffyBox API](https://www.df.eu/at/cloud-hosting/cloud-server/api/).

Original (German)
[PDF Documentation](https://www.df.eu/fileadmin/media/doc/jiffybox-api-dokumentation.pdf).

The JiffyBox API is a simple HTTP REST API.

This library uses the request, rate limiter, and bluebird Promise library to
make the API usage a bit more comfortable (and honor the API limits!).

## Sample Usage

```javascript
var client = require("jiffybox")("API KEY HERE");

// Get a listing of your JiffyBoxes
client.getJiffyBoxes().then(function(boxes){
  // boxes is Array of data from Webservice
})

// Using bluebird promises, create a box & wait for it to be ready
Promise.try(function(){
  return [
    client.getDistros(),
    client.getPlans()
  ]
})
.spread(function(distros, plans){
  client.createJiffyBox({
    name: "TestBox",
    planid: pickPlan(plans),           // your own function!
    distribution: pickDistro(distros), // your own function!
    password: "super secret password",
  })
})
.then(function(box){
  isReady = function(box){ return box.running && box.status === "READY"};
  client.waitForStatus(box.id, isReady)
})
.then(function(box){
  console.log("Your JiffyBox '" + box.name + "' is ready")
})
.catch(function(e){
  console.error(e)
})
```

## Methods

You must first always provide your API key to create a client:

```javascript
var client = require("jiffybox")(apiKey);
```

***NOTE***: the JiffyBox API often returns lists of things (servers, plans,
distributions) as an object, where I preferred an array. In these cases, this
library converts it to an array of objects, adding the property "key" to each
entry (which is sometimes needed). The property "key" is not native to the
JiffyBox API, but all other properties refer directly to the API objects.

## Promise-based API

All other methods return a Promise for a value. Only the value is described
below!


### client.getDistros()

Gets an array of currently available distributions. Each distro has:

- minDiskSizeMB (e.g. 2048)
- name (e.g. 'Debian Jessie (8) 64-Bit')
- rootdiskMode (e.g. 'ro')
- defaultKernel (e.g. 'xen-pvops-x86\_64')
- key (e.g. 'debian\_jessie\_64bit')


### client.getPlans()

Gets an array of currently available server plans. Each plan has:

- id (e.g. 20, needed for creating JiffyBox)
- name (e.g. 'CloudLevel 1', see JiffyBox products)
- diskSizeInMB (e.g. 76800)
- ramInMB (e.g. 2048)
- pricePerHour (e.g. 0.02, Euro/hour when active)
- pricePerHourFrozen (e.g. 0.005, Euro/hour when frozen)
- cpus (e.g. 3)
- key (e.g. '20')


### client.getBackups()

Gets an array of available backups. Each backup has:

- daily: backup object
- weekly: backup object
- biweekly: backup object
- key: string, corresponds to the JiffyBox ID backups are for

Each backup object has:

- id: string
- created: UNIX timestamp


### client.createJiffyBox(options)

Creates a brand-new JiffyBox. According to the API, the following properties
must be given:

- name (string: unique to account, max 30 chars, and may contain spaces and the
  following characters: "a-zA-Z0-9üöäÜÖÄß\_()=!\*@.-"
- planid: must match either **id** or **name** of one of the plans

And you also have to have ***exactly one** of these, NOT both:

- backupid: from `client.getBackups()` (to clone from a backup)
- distribution: from `client.getDistros()`, corresponds to **key** property

The following are optional:

- password: (string) set the root password instead of creating a random one
- use_sshkey: (bool) sets up root login to accept SSH keys (setup via JiffyBox
  control panel required)
- metadata: (object) arbitrary metadata

### client.getJiffyBoxes()

Gets all JiffyBoxes for your account. Refer to the API for full
documentation. These are the ones I find most useful:

- id (number) used for deletion and status changing
- name (string) the unique name for the server
- ips: (object)
  - public: array of public IP addresses
  - private: array of private IP addresses (internal JiffyBox network)
- status (string)

### client.getJiffyBox(id)

Gets data for a single JiffyBox. See `client.getJiffyBoxes()`

### client.deleteJiffyBox(id)

Deletes a single JiffyBox. Note that the status must first be "SHUTDOWN".

### client.setStatus(id, status)

Sets the status of a single JiffyBox. Most useful values of status are:

- "START": starts the server
- "SHUTDOWN": shuts down the server
- "PULLPLUG": perform a pull-the-plug, i.e. immediate power off
- "FREEZE": freezes the box
- "THAW": unfreezes the box

Usually you will use the next method instead...


### client.setStatusAndWait(id, nextStatus, checkStatus)

Sets the status and waits until the status was adopted (internally polling every
5 seconds to check the status).

The parameter **nextStatus** is a string (see `client.setStatus()`).

The parameter **checkStatus** is either a string or function. If a string, the
Promise will be fulfilled as soon as the JiffyBox's **status** field matches
this. If a function (better for API), the function will be called on every
internal polling to see if the status is done.

Here are two examples from the tests:

```javascript
// for starting up
function boxIsReady(box) {
  return box.status === "READY" && box.running;
}
client.setStatusAndWait(id, "START", boxIsReady);

// for shutting down
function boxIsShutdown(box) {
  return box.status === "READY" && ! box.running;
}
client.setStatusAndWait(id, "SHUTDOWN", boxIsShutdown);
```

### client.waitForStatus(id, checkStatus)

Similar to `client.setStatusAndWait()`, but does not try to set a status. Used
internally, but if you never set a status elsewhere, this could hang
forever. However, you could use the
[bluebird Promise.timeout API](http://bluebirdjs.com/docs/api/timeout.html) to
ensure it does not do so.
