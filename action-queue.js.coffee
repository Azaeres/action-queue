_ = require 'underscore'

class ActionQueue
  constructor: ->
    @_seq = []
    @_cur = []
    @_cb = ->

    @_waiting = false
  
  # Adds an action to the currect step.
  addAction: (func, args) =>
    if _.isFunction(func)
      @_cur.push
        func: func
        args: args || []

    else
      throw "`addAction`: Argument 1 must be a function."
    @

  
  # A step is a sequence of actions.
  # `endStep` pushes all the actions that have been added so far into the 
  # next step.
  endStep: =>
    @_seq.push @_cur
    @_cur = []
    @

  
  # Runs through all the actions in a step.
  # Actions are called on an internal delegate object.
  # When a step is done, it's removed from the queue.
  runNextStep: =>
    unless @_waiting
      step = @_seq[0]
      unless _.isUndefined(step)
        @_seq.splice 0, 1
        _(step).each (action) ->
          if (action.args.length > 0)
            action.func.apply action.args
          else
            action.func()

        @_cb()  unless @_waiting
    @

  
  # Sets a callback function to call when the queue stops waiting.
  onComplete: (callback) =>
    @_cb = callback  if _.isFunction(callback)
    @

  
  # If you've called `wait`, this tells the action queue to stop waiting
  # and call the callback (if one was given at the call to `wait`).
  complete: =>
    if @_waiting
      @_waiting = false
      @_cb()
    @

  
  # Tells the action queue to wait.
  # While waiting, all calls to `runNextStep` do nothing.
  # Give it a callback function to execute when it should stop waiting.
  # Will wait until `complete` is called.
  wait: (callback) =>
    @onComplete callback
    @_waiting = true
    @

  
  # For debug purposes.
  # Returns the current action sequence, so it can be inspected.
  state: =>
    Steps: @_seq
    "Current step": @_cur
    Callback: @_cb
    Waiting: @_waiting

module.exports = ActionQueue
