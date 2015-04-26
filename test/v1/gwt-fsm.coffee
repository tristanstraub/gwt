# Test with quickcheck/fsm style checking
#
I = require 'immutable'
async = require 'async'
gwt = require '../../src'
sinon = require 'sinon'
assert = require 'assert'
Q = require 'q'
cbw = require 'cbw'

{runTests} = require '../../src/fsm'

getSpec = ->
  return {
    Model: ->
      Runner = (modelOutput = '', run = false, steps = true) ->
        given: if steps then (name) -> Runner(modelOutput + name, true)
        when: if steps then (name) ->  Runner(modelOutput + name, true)
        then: if steps then (name) ->  Runner(modelOutput + name, true)
        run: if run then -> Runner(modelOutput, false, false)
        getModelOutput: -> modelOutput

      StepBuilder = (steps = []) ->
        add: (type, description) ->
          StepBuilder(steps.concat [type, description])

      return I.Map steps: StepBuilder(), runner: null, toRunnerModel: ({model}) -> model.set 'runner', Runner()

    Actual: ->
      output = {value: ''}
      return I.Map {
        stepDefinitions:
          GIVEN: 'one': -> output.value += 'one'
          WHEN: 'two': -> output.value += 'two'
          THEN: 'three': -> output.value += 'three'
        steps: null
        getOutput: -> output.value
      }

    # Get allowable actions
    getActionMap: ({model}) -> [
      preCondition: ({model}) -> not model.get('runner')
      getActions: ({model}) -> [
        name: 'steps'
        # fn: function to apply to real state
        fn: ({actual}) ->
          return actual: actual.setIn ['steps'], gwt.steps(actual.get('stepDefinitions'))

        modelFn: ({model}) -> model: model.get('toRunnerModel')({model})

        postCondition: ({model, actual}) -> true
      ]
    ,
      preCondition: ({model}) -> model.get('runner')?.when?
      getActions: ({model}) -> [
        name: 'when'
        # fn: function to apply to real state
        fn: ({actual}) ->
          return actual: actual.updateIn ['steps'], (steps) -> steps.when 'two'

        modelFn: ({model}) -> model: model.updateIn ['runner'], (runner) -> runner.when 'two'

        postCondition: ({model, actual}) -> true
      ]
    ,
      preCondition: ({model}) -> model.get('runner')?.run?
      getActions: ({model}) -> [
        name: 'run'
        fn: ({actual}) ->
          return Q.denodeify((cb) -> actual.get('steps').run cb)().then -> {actual}

        modelFn: ({model}) -> model: model.updateIn ['runner'], (runner) -> runner.run()

        postCondition: ({model, actual}) ->
          assert actual, 'Actual'
          return actual.get('getOutput')() is model.get('runner').getModelOutput()
      ]
    ]
  }

describe 'Simple steps', ->

  it 'should generate a set of steps', (done) ->
    @timeout 1000

    runTests(getSpec())
      .then -> done()
      .fail (err) -> done err
