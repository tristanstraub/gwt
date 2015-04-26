assert = require 'assert'
Q = require 'q'

{generators} = require 'jsquickcheck'


stepActionGenerator = ({actionMap, model}) ->
  if actionMap.length is 1 then return actionMap[0]

  return actionMap[generators.integer(0, actionMap.length - 1)()]

actionMapper = ({model, actions}) ->
  return actions.filter (actionGen) ->
    actionGen.preCondition {model}
  .map (actionGen) -> actionGen.getActions {model}
  .reduce (actions, nextActions) ->
    actions.concat nextActions
  , []

generateActions = ({Model, getActionMap}) ->
  model = Model()
  assert model, 'model from Model()'
  actions = []
  lastAction = null

  for i in [0..100]
    lastAction = null

    tries = 100
    while tries-- > 0 and (not lastAction)
      actionMap = actionMapper model: model, actions: getActionMap {model}
      lastAction = stepActionGenerator({actionMap, model})

    if lastAction
      actions.push lastAction
      {model} = lastAction.modelFn({model})
      assert model, 'Model from modelFn'

  return actions

playbackActions = ({spec, actions}) ->
  #console.log 'Actions:', actions.map (a) -> a.name

  deferred = Q.defer()

  deferred.resolve actual: spec.Actual(), model: spec.Model()

  return actions.reduce (promise, action) ->
    return promise.then ({actual, model}) ->
      Q(action.fn({actual})).then ({actual}) ->
        Q(action.modelFn({model})).then ({model}) ->
          next = {actual, model}

          assert action.postCondition next

          return next
  , deferred.promise

runTests = (spec) ->
  deferred = Q.defer()
  deferred.resolve()

  return [0..10].reduce (promise, i) ->
    promise.then -> playbackActions({actions: generateActions(spec), spec})
  , deferred.promise

module.exports = {runTests}
