noflo = require 'noflo'

class ListenRuntime extends noflo.Component
  constructor: ->
    @element = null
    @inPorts = new noflo.InPorts
      runtime:
        datatype: 'object'
        description: 'FBP Runtime instance'
        required: true
    @outPorts = new noflo.OutPorts
      connected:
        datatype: 'object'
        description: 'FBP Runtime instance'
        required: true
      disconnected:
        datatype: 'object'
        description: 'Runtime connection error'
        required: false
    # TODO: listen to status too?

    @inPorts.on 'runtime', 'data', (runtime) =>
      @updateListeners runtime

  updateListeners: (runtime) ->
    @removeListeners()
    @runtime = runtime
    @runtime.on 'connected', @onConnected
    @runtime.on 'disconnected', @onDisconnected

  removeListeners: () ->
    return unless @runtime
    @runtime.removeListener 'connected', @onConnected
    @runtime.removeListener 'disconnected', @onDisconnected

  onConnected: () =>
    @outPorts.connected.send @runtime
    @outPorts.connected.disconnect()

  onDisconnected: () =>
    @outPorts.disconnected.send @runtime
    @outPorts.disconnected.disconnect()

  shutdown: () ->
    @removeListener()

exports.getComponent = -> new ListenRuntime
