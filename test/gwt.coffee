async = require 'async'
bdd = require '../src'
sinon = require 'sinon'
assert = require 'assert'
Q = require 'q'
cbw = require 'cbw'

callAndPromise = (asyncFunction) ->
  return Q.denodeify(asyncFunction)()


describe 'bdd', ->
  @timeout 500

  describe 'with substitutions', ->
    feature = ->
      return declareStepsAndScenario
        steps:
          GIVEN: 'a condition ${condition}': sinon.spy ({condition}) ->
          WHEN: 'something is done ${action}': sinon.spy ({action}) ->
          THEN: 'I expect a result ${expectation}': sinon.spy ({expectation}) ->

        scenario: (runner) ->
          runner
            .given 'a condition ${condition}', condition: 'one'
            .when 'something is done ${action}', action: 'two'
            .then 'I expect a result ${expectation}', expectation: 'three'

    it 'should call `it` with description', (done) ->
      feature().run cbw(done) ({bddIt}) ->
        assert.equal bddIt.getCall(0).args[0],
          'Given a condition one, when something is done two, then I expect a result three'
        done()

    it 'should generate one test', (done) ->
      feature().run cbw(done) ({tests}) ->
        assert.equal tests.length, 1
        done()

    it 'should call GIVEN with substitution', (done) ->
      ({steps} = feature()).run cbw(done) ({tests}) ->
        assert steps.GIVEN['a condition ${condition}'].calledWith condition: 'one'
        done()

    it 'should call WHEN with substitution', (done) ->
      ({steps} = feature()).run cbw(done) ({tests}) ->
        assert steps.WHEN['something is done ${action}'].calledWith action: 'two'
        done()

    it 'should call THEN with substitution', (done) ->
      ({steps} = feature()).run cbw(done) ({tests}) ->
        assert steps.THEN['I expect a result ${expectation}'].calledWith expectation: 'three'
        done()


  describe 'with promises', ->
    feature = (onCalled) ->
      return declareStepsAndScenario
        steps:
          GIVEN: 'a condition ${condition}': ({condition}) ->
            return callAndPromise (cb) ->
              onCalled.given = true
              cb null
          WHEN: 'something is done ${action}': ({action}) ->
            return callAndPromise (cb) ->
              onCalled.when = true
              cb null
          THEN: 'I expect a result ${expectation}': ({expectation}) ->
            return callAndPromise (cb) ->
              onCalled.then = true
              cb null

        scenario: (runner) ->
          runner
            .given 'a condition ${condition}', condition: 'one'
            .when 'something is done ${action}', action: 'two'
            .then 'I expect a result ${expectation}', expectation: 'three'


    it 'should resolve GIVEN promise', (done) ->
      feature(onCalled = {}).run cbw(done) ->
        assert.equal onCalled.given, true
        done()

    it 'should resolve WHEN promise', (done) ->
      feature(onCalled = {}).run cbw(done) ->
        assert.equal onCalled.when, true
        done()

    it 'should resolve THEN promise', (done) ->
      feature(onCalled = {}).run cbw(done) ->
        assert.equal onCalled.then, true
        done()


  describe 'with resultTo', ->
    feature = (result) ->
      return declareStepsAndScenario
        steps:
          GIVEN: {}
          WHEN: 'something is done ${action}': ({@action}) ->
            return "(#{@action})"
          THEN: {}

        scenario: (runner) ->
          runner
            .when('something is done ${action}', action: 'two').resultTo(result)

    it 'should push result to result object', (done) ->
      feature(result = bdd.result()).run cbw(done) ->
        result
          .then (resultValue) ->
            assert.equal resultValue, '(two)'
            done()
          .fail done


  describe 'combine()', ->
    it 'should run one set of steps after the other', (done) ->
      ce = cbw done

      feature1 = declareStepsAndScenario
        steps:
          GIVEN: 'a condition ${condition}': sinon.spy ({@condition}) ->

        scenario: (runner) ->
          runner
            .given 'a condition ${condition}', condition: 'one'

      feature2 = declareStepsAndScenario
        steps:
          WHEN: 'something is done ${action}': sinon.spy ({@action}) ->
            return "(#{@action})"

        scenario: (runner) ->
          runner
            .when('something is done ${action}', action: 'two')#.resultTo(result)

      feature3 = declareStepsAndScenario
        steps:
          THEN: 'something should have happened': sinon.spy ->

        scenario: (runner) ->
          runner
            .then 'something should have happened'

      {steps: steps1} = feature1
      {steps: steps2} = feature2
      {steps: steps3} = feature3

      feature1.combine(feature2).combine(feature3).run ce ->
        try
          assert steps1.GIVEN['a condition ${condition}'].called, 'First feature steps not called'
          assert steps2.WHEN['something is done ${action}'].called, 'Second feature steps not called'
          assert steps3.THEN['something should have happened'].called, 'Third feature steps not called'
        catch e
          return done e
        done()


  describe 'with context', ->
    feature = ->
      return declareStepsAndScenario
        steps:
          GIVEN: 'a condition ${condition}': ({@condition}) ->
          WHEN: 'something is done ${action}': ({@action}) ->
          THEN: 'I expect a result ${expectation}': ({@expectation}) ->

        scenario: (runner) ->
          runner
            .given 'a condition ${condition}', condition: 'one'
            .when 'something is done ${action}', action: 'two'
            .then 'I expect a result ${expectation}', expectation: 'three'
    # TODO unfinished



createTestContext = ->
  tests = []
  bddIt = sinon.spy (name, fn) ->
    tests.push fn

  run = ({runner}, cb) ->
    # Side effect: calls `it`, because `steps.done` is called inside scenario()
    runner.done it: bddIt

    async.series tests, cbw(cb) ->
      cb null, {bddIt, tests}

  return {bddIt, tests, run}


buildTestRunner = ({runner, steps, run}) ->
  assert runner, 'Runner not defined'

  return {
    steps
    runner

    run: (cb) -> run {runner}, cb

    combine: (suffixRunner) ->
      assert suffixRunner.runner, 'SuffixRunner.runner not defined'
      return buildTestRunner {runner: bdd.combine(runner, suffixRunner.runner), steps, run}
  }

declareStepsAndScenario = ({steps, scenario}) ->
  do (bddIt = null, tests = null) ->
    {run, bddIt, tests} = createTestContext()

    runner = scenario(bdd.accordingTo(-> steps).getRunner())

    return buildTestRunner {runner, steps, run}
