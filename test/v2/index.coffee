# Test with quickcheck/fsm style checking
#
I = require 'immutable'
async = require 'async'
gwt = require '../../src'
sinon = require 'sinon'
assert = require 'assert'
Q = require 'q'
cbw = require 'cbw'
R = require 'ramda'

{runTests} = require '../../src/fsm'


assertKeys = (args) ->
  for key, value of args
    assert value?, key

createGwt = ({buildLibrary, buildScenario, buildRunner, addNextStepToScenario, addStepDefinitionToLibrary, getStepsFromRunner, bakeLibrarySteps}) ->
  assertKeys {buildLibrary, buildScenario, buildRunner, addNextStepToScenario, addStepDefinitionToLibrary, getStepsFromRunner, bakeLibrarySteps}

  Library = (library) ->
    next = R.curry(R.compose(Library, addStepDefinitionToLibrary))(library)

    given: (description, value) -> next 'given', description, value
    when: (description, value) -> next 'when', description, value
    then: (description, value) -> next 'then', description, value

    toScenario: -> Scenario buildScenario {library}

  Scenario = (scenario) ->
    next = R.curry(R.compose Scenario, addNextStepToScenario)(scenario)

    given: (description, args...) -> next 'given', description, args
    when: (description, args...) -> next 'when', description, args
    then: (description, args...) -> next 'then', description, args

    toRunner: ->
      steps = bakeLibrarySteps {scenario}
      Runner buildRunner {steps}

  Runner = (runner) ->
    run: ->
      for {category, description, fn} in getStepsFromRunner({runner})
        console.log 'running:', category, description
        fn()

  return {createLibrary: R.compose Library, buildLibrary}


buildLibrary = ->
  {definitions: I.Map()}

buildScenario = ({library}) ->
  assertKeys {library}

  I.Map {library, steps: I.List()}

bakeLibrarySteps = ({scenario}) ->
  assertKeys {scenario}

  library = scenario.get 'library'
  steps = scenario.get 'steps'

  interpolate = (description, args) ->
    description

  return I.List steps.toJS().map ({category, description, args}) ->
    {category, description: interpolate(description, args), fn: -> console.log 'step:', description}

buildRunner = ({steps}) ->
  I.Map {steps}

addNextStepToScenario = (scenario, category, description, args) ->
  scenario.updateIn ['steps'], (steps) ->
    steps.push {category, description, args}

addStepDefinitionToLibrary = (library, category, description, value) ->
  library

getStepsFromRunner = ({runner}) ->
  runner.getIn(['steps']).toJS()

it.only 'test new build', (done) ->
  {createLibrary} = createGwt({buildLibrary, buildScenario, buildRunner, addNextStepToScenario, addStepDefinitionToLibrary, getStepsFromRunner, bakeLibrarySteps})

  Q(createLibrary()
      .given('test').when('testing').then('ok')
      .toScenario()
      .given('test').when('testing').then('ok')
      .toRunner()
      .run())
    .then -> done()
