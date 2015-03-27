# TODO do promiseBuilder chaining at the very end, when done is called, because the composibility is
# broken.

Q = require 'q'
_ = require 'lodash'
assert = require 'assert'

exports.result = ->
  deferredBuilder = Q.defer()
  return {
    resolve: (args...) -> deferredBuilder.resolve args...
    then: (args...) -> deferredBuilder.promise.then args...
    fail: (args...) -> deferredBuilder.promise.fail args...
  }


exports.combine = (leftRunner, rightRunner) ->
  assert leftRunner, 'left runner not defined'
  assert rightRunner, 'right runner not defined'

  return leftRunner.combine rightRunner


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

deepPromiseResolve = (object) ->
  Q(object).then (object) ->
    if !object then return
    if typeof object isnt 'object' then return object
    if object instanceof Date then return object
    if object instanceof RegExp then return object

    deferred = Q.defer()
    promise = deferred.promise

    if Array.isArray(object)
      # Rewrite with reduce
      for key in [0...object.length]
        do (key, value = object[key]) ->
          promise = promise.then ->
            deepPromiseResolve(value).then (innerValue) ->
              object[key] = innerValue
    else
      # Rewrite with reduce
      for key, value of object
        do (key, value) ->
          promise = promise.then ->
            deepPromiseResolve(value).then (innerValue) ->
              object[key] = innerValue

    promise = promise.then -> return object

    deferred.resolve()

    return promise

describeScenario = (spec, {only, counts}) ->
  {GIVEN, WHEN, THEN, DONE} = spec

  getter = (name, collection) -> (description) ->
    fn = collection[description]
    if !fn then throw new Error "'#{name}' doesn't contain '#{description}'"
    return (context, extraContext, args) ->
      # Isolate from previous context. Not sure this is useful currently.
      newContext = _.extend {}, context, extraContext
      newContext.updateContext()
      # resolve promises contained in args. Use inplace replacement for the moment.
      deepPromiseResolve(args).then (args) ->
        Q(fn.apply newContext, args).then (result) ->
          # Pipe result to resultTo
          newContext._last_result = result
          counts[name].called description
          # fn mutated context
          newContext

  getGiven = getter 'GIVEN', GIVEN
  getWhen = getter 'WHEN', WHEN
  getThen = getter 'THEN', THEN

  deferred = Q.defer()
  deferredBuilder =
    promiseBuilder: deferred.promise
    resolve: (args...) -> deferred.resolve args...

  bdd = (descriptionBuilder, promiseBuilder) ->
    assert promiseBuilder, 'bdd required promiseBuilder'
    # Used by combine for chaining
    deferredBuilder: deferredBuilder
    promiseBuilder: promiseBuilder

    resultTo: (result) ->
      assert result, 'Result must be a promiseBuilder. Create one with bdd.result()'

      bdd(descriptionBuilder,
        promiseBuilder.then (context) ->
          console.log 'resolve', context._last_result
          result.resolve context._last_result
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
      promiseBuilder.then (context) ->
        currentContext = null
        updateContext = -> currentContext = this
        rightBdd.deferredBuilder.resolve({getContext: (-> currentContext), updateContext})

      return bdd(descriptionBuilder, rightBdd.promiseBuilder)

    done: ({it: bddIt} = {}) ->
      bddIt ?= global.it
      bddIt = if only then bddIt.only.bind(bddIt) else bddIt

      bddIt descriptionBuilder.get(), (done) ->
        finish = ->
          spec.done?()
          done()
        promiseBuilder.then (-> done()), ((err) ->
          console.error err.stack
          done err)

        currentContext = null
        updateContext = -> currentContext = this
        deferredBuilder.resolve({getContext: (-> currentContext), updateContext})

  return bdd(buildDescription(), deferredBuilder.promiseBuilder)

interpolate = (description, args) ->
  kw = _.last(args)
  description.replace /[$]{([^}]*)}/g, (fullMatch, name, position, currentDescription) ->
    assert kw, "Keyword arguments not passed to spec description '#{description}'"
    kw[name]
