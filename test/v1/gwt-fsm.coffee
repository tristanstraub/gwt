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

stepActionGenerator = ({actionMap, modelSteps}) ->
  actionMap.filter (a) -> a.preCondition {modelSteps}
  actionMap[generators.integer(0, actionMap.length - 1)()]

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

  spec = ->
    ModelSteps: ModelSteps = (modelOutput = '') ->
      return {
        given: (name) -> ModelSteps(modelOutput + name)
        when: (name) ->  ModelSteps(modelOutput + name)
        then: (name) ->  ModelSteps(modelOutput + name)
        getModelOutput: -> modelOutput
      }

    # fn: function to apply to real state
    actions: [
      # Model based preCondition condition
      preCondition: ({modelSteps}) -> modelSteps.given?
      # Real update
      fn: (steps) -> steps.given 'one'
      # Model update
      modelFn: (modelSteps) -> modelSteps.given 'one'
      # Comparison between model and real
      postCondition: ({modelSteps, steps}) -> true
    ,
      preCondition: ({modelSteps}) -> modelSteps.when?
      fn: (steps) -> steps.when 'two'
      modelFn: (modelSteps) -> modelSteps.when 'two'
      postCondition: ({modelSteps, steps}) -> true
    ,
      preCondition: ({modelSteps}) -> modelSteps.then?
      fn: (steps) -> steps.then 'three'
      modelFn: (modelSteps) -> modelSteps.then 'three'
      postCondition: ({modelSteps, steps}) -> true
    ]

  it 'should generate a set of steps', (done) ->
    output = ''

    {ModelSteps, actions: actionMap} = spec()

    getActual = ->
      return gwt.steps
        GIVEN: 'one': -> output += 'one'
        WHEN: 'two': -> output += 'two'
        THEN: 'three': -> output += 'three'

    actions = []
    lastAction = null
    modelSteps = ModelSteps()
    for i in [0..10]
      lastAction = stepActionGenerator({actionMap, modelSteps})
      while not lastAction.preCondition {modelSteps}
        lastAction = stepActionGenerator({actionMap, modelSteps})
      actions.push lastAction
      modelSteps = lastAction.modelFn(modelSteps)

    {steps, modelSteps} = actions.reduce ({steps, modelSteps}, action) ->
      next =
        steps: action.fn(steps)
        modelSteps: action.modelFn(modelSteps)

      assert action.postCondition next

      return next
    , {steps: getActual(), modelSteps: ModelSteps()}

    steps.run cbw(done) ->
      assert.equal output, modelSteps.getModelOutput()
      done()
