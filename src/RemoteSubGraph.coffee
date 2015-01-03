noflo = require 'noflo'
connection = require './connection'

class RemoteSubGraph extends noflo.Component

  constructor: (metadata) ->
    metadata = {} unless metadata

    @runtime = null
    @ready = false

    @inPorts = new noflo.InPorts
    @outPorts = new noflo.OutPorts
    # TODO: add connected/disconnected output port by default

  isReady: ->
    @ready
  setReady: (ready) ->
    @ready = ready
    @emit 'ready' if ready

  start: ->
    @runtime.start()
    super()

  setDefinition: (definition) ->
    @definition = definition
    try
      Runtime = require "./runtimes/#{definition.protocol}"
    catch e
      throw new Error "'#{@definition.protocol}' protocol not supported: " + e.message
    @runtime = new Runtime @definition

    @description = definition.description || ''
    @setIcon definition.icon if definition.icon

    @runtime.on 'capabilities', (capabilities) =>
      if 'protocol:runtime' not in capabilities
        throw new Error "runtime #{@definition.id} does not declare protocol:runtime"
      if definition.graph
        noflo.graph.loadFile definition.graph, (graph) =>
          connection.sendGraph graph, @runtime, =>
            @runtime.setMain graph

    # TODO: make runtime base handle ports discovery similar to capabilities?
    portsRecv = 0
    @runtime.on 'runtime', (msg) =>
      if msg.command == 'ports'
        @setupPorts msg.payload
      else if msg.command == 'packet'
        @onPacketReceived msg.payload

    @runtime.on 'connected', () =>
      #
    @runtime.on 'error', () =>
      console.log 'error'

    # Attempt to connect
    @runtime.connect()

  setupPorts: (ports) ->
    @setReady false
    # Expose remote graph's exported ports as node ports
    @prepareInport port for port in ports.inPorts
    @prepareOutport port for port in ports.outPorts
    setTimeout =>
      @setReady true
    , 100

  prepareInport: (definition) ->
    name = definition.id
    # Send data across to remote graph
    # TODO: set metadata like datatype
    @inPorts.add name, {}, (event, packet) =>
      # TODO: Support for the other event types
      if event isnt 'data'
        console.log 'SENC: ignoring event type', event
        return

      @runtime.sendRuntime 'packet', { port: name, event: 'data', payload: packet }

  prepareOutport: (definition) ->
    name = definition.id
    port = @outPorts.add name, {}

  onPacketReceived: (packet) ->
    # TODO: support the other event types
    if packet.event != 'data'
      console.log 'RECV: ignoring event type', packet.event
      return

    # TODO: set metadata like datatype
    name = packet.port
    port = @outPorts[name]
    port.send packet.payload

  shutdown: ->
    @runtime.disconnect()

exports.RemoteSubGraph = RemoteSubGraph
exports.getComponent = (metadata) -> new RemoteSubGraph metadata
exports.getComponentForRuntime = (runtime, baseDir) ->
  return (metadata) ->
    instance = exports.getComponent metadata
    instance.baseDir = baseDir
    instance.setDefinition runtime
    return instance
