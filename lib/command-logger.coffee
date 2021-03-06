# Originally from lee-dohm/bug-report
# https://github.com/lee-dohm/bug-report/blob/master/lib/command-logger.coffee

moment = null

# Command names that are ignored and not included in the log. This uses an Object to provide fast
# string matching.
ignoredCommands =
  'show.bs.tooltip':        yes
  'shown.bs.tooltip':       yes
  'hide.bs.tooltip':        yes
  'hidden.bs.tooltip':      yes
  'editor:display-updated': yes
  'mousewheel':             yes

# Ten minutes in milliseconds.
tenMinutes = 10 * 60 * 1000

# Public: Handles logging all of the Atom commands for the automatic repro steps feature.
#
# It uses an array as a circular data structure to log only the most recent commands.
module.exports =
class CommandLogger
  @instance: ->
    @_instance ?= new CommandLogger

  @start: ->
    @instance().start()

  # Public: Format of time information.
  dateFmt: '-m:ss.S'

  # Public: Maximum size of the log.
  logSize: 16

  # Public: Creates a new logger.
  constructor: ->
    @initLog()

  start: ->
    atom.commands.onWillDispatch (event) =>
      @logCommand(event)

  # Public: Formats the command log for the bug report.
  #
  # * `externalData` An {Object} containing other information to include in the log.
  #
  # Returns a {String} of the Markdown for the report.
  getText: (externalData) ->
    lines = []
    lastTime = Date.now()

    @eachEvent (event) =>
      return if event.time > lastTime
      return if not event.name or lastTime - event.time >= tenMinutes
      lines.push(@formatEvent(event, lastTime))

    if externalData
      lines.push("     #{@formatTime(0)} #{externalData.title}")

    lines.unshift('```')
    lines.push('```')
    lines.join("\n")

  # Public: Gets the latest event from the log.
  #
  # Returns the event {Object}.
  latestEvent: ->
    @eventLog[@logIndex]

  # Public: Logs the command.
  #
  # * `command` Command {Object} to be logged
  #   * `type` Name {String} of the command
  #   * `target` {String} describing where the command was triggered
  logCommand: (command) ->
    {type: name, target: source, time} = command
    return if command.detail?.jQueryTrigger
    return if name of ignoredCommands

    event = @latestEvent()

    if event.name is name
      event.count++
    else
      @logIndex = (@logIndex + 1) % @logSize
      event = @latestEvent()
      event.name   = name
      event.source = source
      event.count  = 1
      event.time   = time ? Date.now()

  # Private: Calculates the time of the last event to be reported.
  #
  # * `data` Data from an external bug passed in from another package.
  #
  # Returns the {Date} of the last event that should be reported.
  calculateLastEventTime: (data) ->
    return data.time if data

    lastTime = null
    @eachEvent (event) -> lastTime = event.time
    lastTime

  # Private: Executes a function on each event in chronological order.
  #
  # This function is used instead of similar underscore functions because the log is held in a
  # circular buffer.
  #
  # * `fn` {Function} to execute for each event in the log.
  #   * `event` An {Object} describing the event passed to your function.
  #
  # ## Examples
  #
  # This code would output the name of each event to the console.
  #
  # ```coffee
  # logger.eachEvent (event) ->
  #   console.log event.name
  # ```
  eachEvent: (fn) ->
    for offset in [1..@logSize]
      fn(@eventLog[(@logIndex + offset) % @logSize])
    return

  # Private: Format the command count for reporting.
  #
  # Returns the {String} format of the command count.
  formatCount: (count) ->
    switch
      when count < 2 then '    '
      when count < 10 then "  #{count}x"
      when count < 100 then " #{count}x"

  # Private: Formats a command event for reporting.
  #
  # * `event` Event {Object} to be formatted.
  # * `lastTime` {Date} of the last event to report.
  #
  # Returns the {String} format of the command event.
  formatEvent: (event, lastTime) ->
    {count, time, name, source} = event
    "#{@formatCount(count)} #{@formatTime(lastTime - time)} #{name} #{@formatSource(source)}"

  # Private: Format the command source for reporting.
  #
  # * `source` {Object} describing from where the event originated
  #
  # Returns the {String} format of the command source.
  formatSource: (source) ->
    {nodeName, id, classList} = source
    nodeText = nodeName.toLowerCase()
    idText = if id then "##{id}" else ''
    classText = ''
    classText += ".#{klass}" for klass in classList if classList

    "(#{nodeText}#{idText}#{classText})"

  # Private: Format the command time for reporting.
  #
  # * `time` {Date} to format
  #
  # Returns the {String} format of the command time.
  formatTime: (time) ->
    moment ?= require 'moment'
    moment(time).format(@dateFmt)

  # Private: Initializes the log structure for speed.
  initLog: ->
    @logIndex = 0
    @eventLog = for i in [0...@logSize]
      name: null
      count: 0
      source: null
      time: null
