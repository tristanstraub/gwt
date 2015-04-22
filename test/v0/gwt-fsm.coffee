# Test with quickcheck/fsm style checking
#

require 'coffee-errors'

async = require 'async'
gwt = require '../../src'
sinon = require 'sinon'
assert = require 'assert'
Q = require 'q'
cbw = require 'cbw'
{generators} = require 'jsquickcheck'


describe 'Simple steps', ->
  do (steps = null) ->
    steps = gwt.steps
      GIVEN: 'one': ->
      WHEN: 'two': ->
      THEN: 'three': ->

    describe 'multiple it test', ->
      steps
        .given 'one'
        .when 'two'
        .then 'three'
        .done(multipleIt: true)

  it 'should generate a set of steps', (done) ->
    output = ''

    steps = gwt.steps
      GIVEN: 'one': -> output += 'one'
      WHEN: 'two': -> output += 'two'
      THEN: 'three': -> output += 'three'

    ModelSteps = (modelOutput = '') ->
      return {
        given: (name) -> ModelSteps(modelOutput + name)
        when: (name) ->  ModelSteps(modelOutput + name)
        then: (name) ->  ModelSteps(modelOutput + name)
        getModelOutput: -> modelOutput
      }

    # fn: function to apply to real state
    ACTIONS = [
      pre: ({modelSteps}) -> modelSteps.given?
      fn: (steps) -> steps.given 'one'
      modelFn: (modelSteps) -> modelSteps.given 'one'
      post: ({modelSteps, steps}) ->
    ,
      pre: ({modelSteps}) -> modelSteps.when?
      fn: (steps) -> steps.when 'two'
      modelFn: (modelSteps) -> modelSteps.when 'two'
      post: ({modelSteps, steps}) ->
    ,
      pre: ({modelSteps}) -> modelSteps.then?
      fn: (steps) -> steps.then 'three'
      modelFn: (modelSteps) -> modelSteps.then 'three'
      post: ({modelSteps, steps}) ->
    ]
    assert.equal ACTIONS.length, 3, 'actions has 3'

    stepActionGenerator = ({modelSteps}) ->
      ACTIONS.filter (a) -> a.pre {modelSteps}
      ACTIONS[generators.integer(0, ACTIONS.length - 1)()]

    actions = []
    lastAction = null
    modelSteps = ModelSteps()
    for i in [0..10]
      lastAction = stepActionGenerator({modelSteps})
      while not lastAction.pre {modelSteps}
        lastAction = stepActionGenerator({modelSteps})
      actions.push lastAction
      modelSteps = lastAction.modelFn(modelSteps)

    {steps, modelSteps} = actions.reduce ({steps, modelSteps}, action) ->
      next =
        steps: action.fn(steps)
        modelSteps: action.modelFn(modelSteps)

      action.post next

      return next
    , {steps, modelSteps: ModelSteps()}

    steps.run cbw(done) ->
      assert.equal output, modelSteps.getModelOutput()
      done()
