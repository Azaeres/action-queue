assert = require 'assert'
sinon = require 'sinon'
ActionQueue = require '../index'

describe 'ActionQueue', ->
  testAction = (action, numArgs) ->
    numArgs = numArgs || 0
    assert(action, "action should be defined")
    assert(typeof action.func == 'function', "action should have a function")
    assert(action.args instanceof Array, "action's args should be an array")
    assert(action.args.length == numArgs, "action should have "+numArgs+" arguments")

  testActions = (actions, numActions) ->
    assert(actions instanceof Array, "actions should be an array")
    assert(actions.length == numActions, "there should be "+numActions+" actions")

  testSteps = (steps, numSteps) ->
    assert(steps instanceof Array, "steps should be an array")
    assert(steps.length == numSteps, "should have "+numSteps+" steps")

  constructQueue = ->
    queue = new ActionQueue()
    queue.addAction ->
      console.log('step 1, action 1: arguments:\n', arguments)
    queue.addAction ->
      console.log('step 1, action 2: arguments:\n', arguments)
    , ['arg1', 'arg2']
    queue.endStep()
    queue.addAction ->
      console.log('step 2, action 1: arguments, this:\n', arguments, this);
    queue.addAction ->
      console.log('step 2, action 2: arguments:\n', arguments)
    , ['arg1', 'arg2']
    queue.endStep()


  describe '#constructor()', ->
    
    it "should create an action queue", ->
      queue = new ActionQueue()
      assert(queue)

    it "should not be initially waiting", ->
      queue = new ActionQueue()
      state = queue.state()
      assert(state.Waiting == false)

    it "should have no inital steps", ->
      queue = new ActionQueue()
      state = queue.state()
      assert.deepEqual(state.Steps, [])

  describe '#addAction()', ->
    it "should be able to add an action without arguments to the current step", ->
      queue = new ActionQueue()
      queue.addAction ->
        console.log('action 1: arguments:\n', arguments)
      state = queue.state()

      assert(state['Current step'].length == 1, "queue should have 1 action in the current step")
      testAction(state['Current step'][0], 0)

    it "should be able to add an action with arguments to the current step", ->
      queue = new ActionQueue()
      queue.addAction ->
        console.log('action 1: arguments:\n', arguments)
      , ['arg1', 'arg2']
      state = queue.state()

      assert(state['Current step'].length == 1)
      testAction(state['Current step'][0], 2)

    it "must be provided a function as the basis for the action", ->
      queue = new ActionQueue()
      assert.throws ->
        queue.addAction()
      , "should throw an exception when the first argument passed in isn't a function"

    it "should be able to add multiple actions to the current step", ->
      queue = new ActionQueue()
      queue.addAction ->
        console.log('action 1: arguments:\n', arguments)
      queue.addAction ->
        console.log('action 2: arguments:\n', arguments)
      , ['arg1', 'arg2']
      state = queue.state()

      assert.deepEqual(state.Steps, [], "steps should be an empty array")

      # Testing current step
      testActions(state['Current step'], 2)

      # Testing first action
      testAction(state['Current step'][0], 0)

      # Testing second action
      testAction(state['Current step'][1], 2)

  describe '#endStep', ->
    it 'should push all actions to the next step', ->
      queue = new ActionQueue()
      queue.addAction ->
        console.log('action 1: arguments:\n', arguments)
      queue.addAction ->
        console.log('action 2: arguments:\n', arguments)
      , ['arg1', 'arg2']
      queue.endStep()

      state = queue.state()

      # Current step should be empty
      actions = state['Current step']
      assert.deepEqual(actions, [])

      # Testing steps
      steps = state.Steps
      testSteps(steps, 1)

      # Testing first step
      actions = steps[0]
      testActions(actions, 2)

      # Testing first action
      testAction(actions[0], 0)

      # Testing second action
      testAction(actions[1], 2)

    it "should be able to queue up multiple actions after we've ended a step", ->
      queue = new ActionQueue()
      queue.addAction ->
        console.log('step 1, action 1: arguments:\n', arguments)
      queue.addAction ->
        console.log('step 1, action 2: arguments:\n', arguments)
      , ['arg1', 'arg2']
      queue.endStep()
      queue.addAction ->
        console.log('step 2, action 1: arguments, this:\n', arguments, this);
      queue.addAction ->
        console.log('step 2, action 2: arguments:\n', arguments)
      , ['arg1', 'arg2']

      state = queue.state()

      # Current step should have 2 actions
      actions = state['Current step']
      assert(actions.length == 2, "should have 2 actions")

      # Testing steps
      steps = state.Steps
      testSteps(steps, 1)

      # Testing first step
      actions = steps[0]
      testActions(actions, 2)

      # Testing first action
      testAction(actions[0], 0)

      # Testing second action
      testAction(actions[1], 2)

    it "should be able to end multiple steps", ->
      queue = constructQueue()
      state = queue.state()

      # Current step should have 2 actions
      actions = state['Current step']
      assert.deepEqual(actions, [], "there should be no actions in the current step")

      # Testing steps
      steps = state.Steps
      testSteps(steps, 2)

      # Testing first step
      actions = steps[0]
      testActions(actions, 2)
      testAction(actions[0], 0)
      testAction(actions[1], 2)

      # Testing second step
      actions = steps[1]
      testActions(actions, 2)
      testAction(actions[0], 0)
      testAction(actions[1], 2)

  describe "#wait", ->
    it "should set an internal wait flag", ->
      queue = constructQueue()
      queue.wait()
      state = queue.state()

      assert(state.Waiting == true, "wait flag should be true")

    it "should stop waiting", ->
      queue = constructQueue()
      queue.wait()
      queue.complete()
      state = queue.state()

      assert(state.Waiting == false, "wait flag should be true")

  describe "#runNextStep", ->
    it "should not call queued up actions if waiting", ->
      queue = new ActionQueue()
      step1action1 = sinon.spy()
      step1action2 = sinon.spy()
      step2action1 = sinon.spy()
      step2action2 = sinon.spy()
      queue.addAction step1action1
      queue.addAction step1action2
      , ['arg1', 'arg2']
      queue.endStep()
      queue.addAction step2action1
      queue.addAction step2action2
      , ['arg1', 'arg2']
      queue.endStep()
      onComplete = sinon.spy()
      queue.wait()
      queue.runNextStep()

      assert(!step1action1.called, "step1action1 was called, but shouldn't have been")
      assert(!step1action2.called, "step1action2 was called, but shouldn't have been")
      assert(!step2action1.called, "step2action1 was called, but shouldn't have been")
      assert(!step2action2.called, "step2action2 was called, but shouldn't have been")

    it "should call queued up actions in first step if not waiting", ->
      queue = new ActionQueue()
      step1action1 = sinon.spy()
      step1action2 = sinon.spy()
      step2action1 = sinon.spy()
      step2action2 = sinon.spy()
      queue.addAction step1action1
      queue.addAction step1action2
      , ['arg1', 'arg2']
      queue.endStep()
      queue.addAction step2action1
      queue.addAction step2action2
      , ['arg1', 'arg2']
      queue.endStep()
      queue.runNextStep()

      assert(step1action1.called, "step1action1 wasn't called, but should've been")
      assert(step1action2.called, "step1action2 wasn't called, but should've been")
      assert(!step2action1.called, "step2action1 was called, but shouldn't have been")
      assert(!step2action2.called, "step2action2 was called, but shouldn't have been")

    it "should call queued up actions in multiple steps if called repeatedly", ->
      queue = new ActionQueue()
      step1action1 = sinon.spy()
      step1action2 = sinon.spy()
      step2action1 = sinon.spy()
      step2action2 = sinon.spy()
      currentStepAction1 = sinon.spy()
      queue.addAction step1action1
      queue.addAction step1action2
      , ['arg1', 'arg2']
      queue.endStep()
      queue.addAction step2action1
      queue.addAction step2action2
      , ['foo', 'bar']
      queue.endStep()
      queue.addAction currentStepAction1

      state = queue.state()
      steps = state.Steps
      testSteps(steps, 2)
      testActions(state['Current step'], 1)

      queue.runNextStep()

      assert(step1action1.called, "step1action1 wasn't called, but should've been")
      assert(step1action2.called, "step1action2 wasn't called, but should've been")
      assert(!step2action1.called, "step2action1 was called, but shouldn't have been")
      assert(!step2action2.called, "step2action2 was called, but shouldn't have been")
      assert(!currentStepAction1.called, "currentStepAction1 was called, but shouldn't have been")

      state = queue.state()
      steps = state.Steps
      testSteps(steps, 1)

      queue.runNextStep()

      assert(step1action1.called, "step1action1 wasn't called, but should've been")
      assert(step1action2.called, "step1action2 wasn't called, but should've been")
      assert(step2action1.called, "step2action1 wasn't called, but should've been")
      assert(step2action2.called, "step2action2 wasn't called, but should've been")
      assert(!currentStepAction1.called, "currentStepAction1 was called, but shouldn't have been")

      state = queue.state()
      steps = state.Steps
      testSteps(steps, 0)

      queue.runNextStep()

      assert(!currentStepAction1.called, "currentStepAction1 was called, but shouldn't have been")

    it "should call queued up actions in multiple steps, but not if waiting", ->
      queue = new ActionQueue()
      step1action1 = sinon.spy()
      step1action2 = sinon.spy()
      step2action1 = sinon.spy()
      step2action2 = sinon.spy()
      currentStepAction1 = sinon.spy()
      queue.addAction step1action1
      queue.addAction step1action2
      , ['arg1', 'arg2']
      queue.endStep()
      queue.addAction step2action1
      queue.addAction step2action2
      , ['foo', 'bar']
      queue.endStep()
      queue.addAction currentStepAction1
      onComplete = sinon.spy()
      queue.onComplete onComplete
      queue.wait()

      state = queue.state()
      steps = state.Steps
      testSteps(steps, 2)
      testActions(state['Current step'], 1)

      queue.runNextStep()

      assert(!step1action1.called, "step1action1 was called, but shouldn't have been")
      assert(!step1action2.called, "step1action2 was called, but shouldn't have been")
      assert(!step2action1.called, "step2action1 was called, but shouldn't have been")
      assert(!step2action2.called, "step2action2 was called, but shouldn't have been")
      assert(!currentStepAction1.called, "currentStepAction1 was called, but shouldn't have been")
      assert(onComplete.callCount == 0, "onComplete was called "+onComplete.callCount+" times, but should've been called 0 times")

      queue.complete()
      assert(onComplete.callCount == 1, "onComplete was called "+onComplete.callCount+" times, but should've been called 1 times")

      state = queue.state()
      steps = state.Steps
      testSteps(steps, 2)

      queue.runNextStep()

      assert(step1action1.called, "step1action1 wasn't called, but should've been")
      assert(step1action1.calledWith(), "step1action1 was not called without arguments")
      assert(step1action2.called, "step1action2 wasn't called, but should've been")
      assert(step1action2.calledWith('arg1', 'arg2'), "step1action2 wasn't called with the appropriate arguments")
      assert(!step2action1.called, "step2action1 wasn't called, but should've been")
      assert(!step2action2.called, "step2action2 wasn't called, but should've been")
      assert(!currentStepAction1.called, "currentStepAction1 was called, but shouldn't have been")
      assert(onComplete.callCount == 2, "onComplete was called "+onComplete.callCount+" times, but should've been called 2 times")

      state = queue.state()
      steps = state.Steps
      testSteps(steps, 1)

      queue.runNextStep()

      assert(step2action1.called, "step2action1 wasn't called, but should've been")
      assert(step2action2.calledWith(), "step2action1 was not called without arguments")
      assert(step2action2.called, "step2action2 wasn't called, but should've been")
      assert(step2action2.calledWith('foo', 'bar'), "step2action2 wasn't called with the appropriate arguments")
      assert(!currentStepAction1.called, "currentStepAction1 was called, but shouldn't have been")
      assert(onComplete.callCount == 3, "onComplete was called "+onComplete.callCount+" times, but should've been called 3 times")

      queue.runNextStep()

      assert(!currentStepAction1.called, "currentStepAction1 was called, but shouldn't have been")


