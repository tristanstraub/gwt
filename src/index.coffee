# TODO do promiseBuilder chaining at the very end, when done is called, because the composibility is
# broken.

Q = require 'q'
_ = require 'lodash'
assert = require 'assert'
I = require 'immutable'
uuid = require 'node-uuid'

class Result
  constructor: (@id) ->
    assert @id, 'Result id not given'
    @value = null

  getFromContext: (context) ->
    return if @overriden then @value else context[@id]

  setInContext: (context, value) ->
    context[@id] = value

  set: (@value) ->
    @overriden = true

exports.result = makeResult = (id = uuid.v4())->
  return new Result(id)

exports.combine = (leftRunner, rightRunner, rest...) ->
  assert leftRunner, 'left runner not defined'
  assert rightRunner, 'right runner not defined'

  runner = leftRunner.combine rightRunner

  if rest.length
    return exports.combine runner, rest...

  return runner

exports.steps = (spec) ->
  return exports.accordingTo(-> spec).getRunner()

exports.accordingTo = (spec) ->
  assert.equal typeof(spec), 'function', 'Spec must be a function'

  _getRunner = ({only} = {}) ->
    counts = getCounts spec()

    # Allow runner to be reused for multiple scenarios
    return {
      only: if not only then _getRunner(only: true)
      # Scenario must start with 'given'
      given: -> describeScenario(spec(), {only, counts}).given arguments...
      when: -> describeScenario(spec(), {only, counts}).when arguments...
      then: -> describeScenario(spec(), {only, counts}).then arguments...
      verifySpecHasBeenCovered: ->
        it 'Verify that all descriptions in the specification have been covered', ->
          uncovered = counts.getUncovered()

          for description in uncovered.GIVEN
            console.error 'Uncovered GIVEN:', description

          for description in counts.getUncovered().WHEN
            console.error 'Uncovered WHEN:', description

          for description in counts.getUncovered().THEN
            console.error 'Uncovered THEN:', description

          hasUncalled = uncovered.GIVEN.length > 0 or uncovered.WHEN.length > 0 or uncovered.THEN.length > 0
          assert !hasUncalled, "Has uncovered descriptions in specification. #{JSON.stringify uncovered}"
    }

  return getRunner: -> _getRunner()


getCounts = (spec) ->
  keys =
    GIVEN: Object.keys(spec.GIVEN or {})
    THEN: Object.keys(spec.THEN or {})
    WHEN: Object.keys(spec.WHEN or {})

  counts = {GIVEN: {}, WHEN: {}, THEN: {}}

  return {
    GIVEN: called: (description) ->
      counts.GIVEN[description] ?= 0
      counts.GIVEN[description]++
    WHEN: called: (description) ->
      counts.WHEN[description] ?= 0
      counts.WHEN[description]++
    THEN: called: (description) ->
      counts.THEN[description] ?= 0
      counts.THEN[description]++
    getUncovered: ->
      return {
        GIVEN: keys.GIVEN.filter (description) -> !counts.GIVEN[description]
        WHEN: keys.WHEN.filter (description) -> !counts.WHEN[description]
        THEN: keys.THEN.filter (description) -> !counts.THEN[description]
      }
  }

buildDescription = (fullDescription = '') ->
  given: (rest, args) ->
    if fullDescription
      buildDescription "#{fullDescription}, and #{interpolate rest, args}"
    else
      buildDescription "Given #{interpolate rest, args}"
  when: (rest, args) ->
    buildDescription "#{fullDescription}, when #{interpolate rest, args}"
  then: (rest, args) -> buildDescription "#{fullDescription}, then #{interpolate rest, args}"
  get: -> fullDescription
  combine: (nextDescription) ->
    buildDescription "#{fullDescription}#{nextDescription.get()}"

resolveResultArgs = (context, args) ->
  argsCopy = _.clone args

  for i in [0...argsCopy.length]
    argsCopy[i] = resolveResults(context, argsCopy[i])

  return argsCopy

resolveResults = (context, object) ->
  if !object then return
  if typeof object isnt 'object' then return object
  if object instanceof Date then return object
  if object instanceof RegExp then return object

  objectCopy = _.clone object

  if Array.isArray(objectCopy)
    for i in [0...objectCopy.length]
      result = objectCopy[i]
      if result instanceof Result then objectCopy[i] = result.getFromContext(context)

    return objectCopy

  for key, result of objectCopy
    if result instanceof Result then objectCopy[key] = result.getFromContext(context)

  return objectCopy

crossCombineResults = makeResult()
lastResult = makeResult()

describeScenario = (spec, {only, counts}) ->
  {GIVEN, WHEN, THEN, DONE} = spec

  getter = (name, collection) -> (description) ->
    fn = collection[description]
    if !fn then throw new Error "'#{name}' doesn't contain '#{description}'"
    return (context, extraContext, args) ->
      # Isolate from previous context.
      newContext = _.extend {}, context, extraContext
      newContext.updateContext()
      # resolve promises contained in args. Use inplace replacement for the moment.
      Q(fn.apply newContext, resolveResultArgs(crossCombineResults.getFromContext(context) ? {}, args)).then (result) ->
        nextStep = ->
          # Pipe result to resultTo
          # TODO use Result for this
          lastResult.setInContext(newContext, result)
          counts[name].called description
          # fn mutated context
          newContext

        if typeof result is 'function'
          Q.denodeify(result)().then nextStep
        else
          nextStep()

  getGiven = getter 'GIVEN', GIVEN
  getWhen = getter 'WHEN', WHEN
  getThen = getter 'THEN', THEN

  promiseBuilderFactory = ({chain} = {chain:  I.List()}) ->
    return {
      then: (fn) ->
        return promiseBuilderFactory chain: chain.push fn

      resolve: (args...) ->
        deferred = Q.defer()
        deferred.resolve args...
        promise = deferred.promise
        chain.forEach (thenFn) -> promise = promise.then thenFn
        return promise
    }

  bdd = (descriptionBuilder, promiseBuilder) ->
    assert promiseBuilder, 'bdd required promiseBuilder'

    run = (done) ->
      promise = if !done
        deferred = Q.defer()
        done = -> deferred.resolve()
        deferred.promise

      finish = ->
        spec.done?()
        done()

      currentContext = null
      updateContext = -> currentContext = this
      promiseBuilder.resolve({getContext: (-> currentContext), updateContext})
        .then(finish)
        .fail(done)

      return promise

    # Used by combine for chaining
    promiseBuilder: promiseBuilder
    descriptionBuilder: descriptionBuilder

    run: run

    resultTo: (result) ->
      assert result, 'Result must be a promiseBuilder. Create one with bdd.result()'

      bdd(descriptionBuilder,
        promiseBuilder.then (context) ->
          results = crossCombineResults.getFromContext(context) ? {}
          result.setInContext results, lastResult.getFromContext(context)
          crossCombineResults.setInContext context, results
          context)

    given: (description, args...) ->
      expandedDescription = interpolate description, args
      bdd(descriptionBuilder.given(description, args),
        promiseBuilder.then (context) -> getGiven(description) context, {description: expandedDescription}, args)

    when: (description, args...) ->
      expandedDescription = interpolate description, args
      bdd(descriptionBuilder.when(description, args),
        promiseBuilder.then (context) -> getWhen(description) context, {description: expandedDescription}, args)

    then: (description, args...) ->
      expandedDescription = interpolate description, args
      bdd(descriptionBuilder.then(description, args),
        promiseBuilder.then (context) -> getThen(description) context, {description: expandedDescription}, args)

    combine: (rightBdd) ->
      assert rightBdd, 'right bdd not defined'

      # TODO chain promiseBuilders after done is called
      nextPromiseBuilder = promiseBuilder.then (context) ->
        currentContext = null
        updateContext = -> currentContext = this
        newContext = {getContext: (-> currentContext), updateContext}
        crossCombineResults.setInContext newContext, crossCombineResults.getFromContext context
        rightBdd.promiseBuilder.resolve(newContext)

      return bdd(descriptionBuilder.combine(rightBdd.descriptionBuilder), nextPromiseBuilder)

    done: ({it: bddIt} = {}) ->
      bddIt ?= global.it
      bddIt = if only then bddIt.only.bind(bddIt) else bddIt

      bddIt descriptionBuilder.get(), run

  return bdd(buildDescription(), promiseBuilderFactory())

interpolate = (description, args) ->
  kw = _.last(args)
  description.replace /[$]{([^}]*)}/g, (fullMatch, name, position, currentDescription) ->
    assert kw, "Keyword arguments not passed to spec description '#{description}'"
    kw[name]
