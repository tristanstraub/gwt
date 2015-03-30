async = require 'async'
bdd = require '../src'
sinon = require 'sinon'
assert = require 'assert'
Q = require 'q'
cbw = require 'cbw'

callAndPromise = (asyncFunction) ->
  return Q.denodeify(asyncFunction)()


describe 'bdd', ->
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
      feature().runWithIt cbw(done) ({bddIt}) ->
        assert.equal bddIt.getCall(0).args[0],
          'Given a condition one, when something is done two, then I expect a result three'
        done()

    it 'should generate one test', (done) ->
      feature().runWithIt cbw(done) ({tests}) ->
        assert.equal tests.length, 1
        done()

    it 'should call GIVEN with substitution', (done) ->
      ({steps} = feature()).runWithIt cbw(done) ({tests}) ->
        assert steps.GIVEN['a condition ${condition}'].calledWith condition: 'one'
        done()

    it 'should call WHEN with substitution', (done) ->
      ({steps} = feature()).runWithIt cbw(done) ({tests}) ->
        assert steps.WHEN['something is done ${action}'].calledWith action: 'two'
        done()

    it 'should call THEN with substitution', (done) ->
      ({steps} = feature()).runWithIt cbw(done) ({tests}) ->
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
      feature(onCalled = {}).runWithIt cbw(done) ->
        assert.equal onCalled.given, true
        done()

    it 'should resolve WHEN promise', (done) ->
      feature(onCalled = {}).runWithIt cbw(done) ->
        assert.equal onCalled.when, true
        done()

    it 'should resolve THEN promise', (done) ->
      feature(onCalled = {}).runWithIt cbw(done) ->
        assert.equal onCalled.then, true
        done()

  describe 'with resultTo', ->
    feature = (result1, result2) ->
      return declareStepsAndScenario
        steps:
          GIVEN: {}
          WHEN: 'something is done ${action}': ({@action}) ->
            return "(#{@action})"
          THEN: 'with the result': sinon.spy ({result1, result2}) ->
            assert.equal result1, "(two)"
            assert.equal result2, "(three)"

        scenario: (runner) ->
          runner
            .when('something is done ${action}', action: 'two').resultTo(result1)
            .when('something is done ${action}', action: 'three').resultTo(result2)
            .then 'with the result', ({result1, result2})

    it 'should resolve the result object before passing to the next step', (done) ->
      ce = cbw done
      ({steps} = feature(result = bdd.result(), result2 = bdd.result())).runWithIt ce ->
        assert steps.THEN['with the result'].called
        done()

  describe 'with resultTo with result.set() override', ->
    feature = (result1, result2) ->
      return declareStepsAndScenario
        steps:
          GIVEN: {}
          WHEN:
            'something is done ${action}': ({@action}) ->
              return "(#{@action})"

            'result is overriden': ({value}) ->
              result2.set value

          THEN: 'with the result': sinon.spy ({result1, result2}) ->
            assert.equal result1, "(two)"
            assert.equal result2, "(four)"

        scenario: (runner) ->
          runner
            .when('something is done ${action}', action: 'two').resultTo(result1)
            .when('something is done ${action}', action: 'three').resultTo(result2)
            .when('result is overriden', value: '(four)')
            .then 'with the result', ({result1, result2})

    it 'should resolve to overriden value from result.set()', (done) ->
      ce = cbw done
      ({steps} = feature(result = bdd.result(), result2 = bdd.result())).runWithIt ce ->
        assert steps.THEN['with the result'].called
        done()

  describe 'resultTo with combine', ->
    features = ->
      result = bdd.result()

      feature1: declareStepsAndScenario
        steps:
          GIVEN: 'a condition': sinon.spy ->
            return 'a result'

        scenario: (runner) ->
          runner
            .given 'a condition'
            .resultTo result

      feature2: declareStepsAndScenario
        steps:
          THEN: 'the second context': sinon.spy ({result}) ->
            assert.equal result, 'a result'

        scenario: (runner) ->
          runner
            .then 'the second context', {result}

      feature3: declareStepsAndScenario
        steps:
          THEN: 'the third context': sinon.spy ({result}) ->
            assert.equal result, 'a result'

        scenario: (runner) ->
          runner
            .then 'the third context', {result}

    it 'should cross combine', (done) ->
      ce = cbw done
      {feature1, feature2} = features()

      {steps: steps1} = feature1
      {steps: steps2} = feature2

      feature1.combine(feature2).runWithIt ce ->
        assert steps1.GIVEN['a condition'].called, 'First feature steps not called'
        assert steps2.THEN['the second context'].called, 'Second feature steps not called'
        done()

    it 'should be reusable across multiple combines', (done) ->
      ce = cbw done
      {feature1, feature2, feature3} = features()

      {steps: steps1} = feature1
      {steps: steps2} = feature2
      {steps: steps3} = feature3

      feature1.combine(feature2).combine(feature3).runWithIt ce ->
        assert steps1.GIVEN['a condition'].called, 'First feature steps not called'
        assert steps2.THEN['the second context'].called, 'Second feature steps not called'
        assert steps3.THEN['the third context'].called, 'Third feature steps not called'
        done()


  describe 'combine() context', ->
    features = ->
      feature1: declareStepsAndScenario
        steps:
          GIVEN: 'a condition': sinon.spy ->
            @value = 'a value'
          THEN: 'the first context': sinon.spy ->
            assert.equal @value, 'a value'

        scenario: (runner) ->
          runner
            .given 'a condition'
            .then 'the first context'

      feature2: declareStepsAndScenario
        steps:
          THEN: 'the second context': sinon.spy ->
            assert !@value

        scenario: (runner) ->
          runner
            .then('the second context')

    it 'should not leak context across combine', (done) ->
      ce = cbw done
      {feature1, feature2} = features()

      {steps: steps1} = feature1
      {steps: steps2} = feature2

      feature1.combine(feature2).runWithIt ce ->
        assert steps1.GIVEN['a condition'].called, 'First feature steps not called'
        assert steps1.THEN['the first context'].called, 'Second feature steps not called'
        assert steps2.THEN['the second context'].called, 'Third feature steps not called'
        done()

  describe 'combine() descriptions', ->
    features = ->
      feature1: declareStepsAndScenario
        steps:
          GIVEN: 'a condition': ->

        scenario: (runner) ->
          runner
            .given 'a condition'

      feature2: declareStepsAndScenario
        steps:
          WHEN: 'something is done': ->

        scenario: (runner) ->
          runner
            .when('something is done')


    it 'should run one step after the other', (done) ->
      ce = cbw done
      {feature1, feature2} = features()

      feature1.combine(feature2).runWithIt ce ({bddIt}) ->
        assert.equal bddIt.getCall(0).args[0], 'Given a condition, when something is done'
        done()

  describe 'combine()', ->
    features = ->
      feature1: declareStepsAndScenario
        steps:
          GIVEN: 'a condition ${condition}': sinon.spy ({@condition}) ->

        scenario: (runner) ->
          runner
            .given 'a condition ${condition}', condition: 'one'

      feature2: declareStepsAndScenario
        steps:
          WHEN: 'something is done ${action}': sinon.spy ({@action}) ->
            return "(#{@action})"

        scenario: (runner) ->
          runner
            .when('something is done ${action}', action: 'two')

      feature3: declareStepsAndScenario
        steps:
          THEN: 'something should have happened': sinon.spy ->

        scenario: (runner) ->
          runner
            .then 'something should have happened'

    it 'should run one step after the other', (done) ->
      ce = cbw done
      {feature1, feature2} = features()

      {steps: steps1} = feature1
      {steps: steps2} = feature2

      feature1.combine(feature2).runWithIt ce ->
        assert steps1.GIVEN['a condition ${condition}'].called, 'First feature steps not called'
        assert steps2.WHEN['something is done ${action}'].called, 'Second feature steps not called'
        done()

    it 'should run one set of steps after the other', (done) ->
      ce = cbw done
      {feature1, feature2, feature3} = features()

      {steps: steps1} = feature1
      {steps: steps2} = feature2
      {steps: steps3} = feature3

      feature1.combine(feature2, feature3).runWithIt ce ->
        assert steps1.GIVEN['a condition ${condition}'].called, 'First feature steps not called'
        assert steps2.WHEN['something is done ${action}'].called, 'Second feature steps not called'
        assert steps3.THEN['something should have happened'].called, 'Third feature steps not called'
        done()

    it 'should not execute promises more than once when features are reused', (done) ->
      ce = cbw done
      {feature1, feature2, feature3} = features()

      run1 = feature1.combine(feature2).combine(feature3)

      {steps: steps1} = feature1
      {steps: steps2} = feature2
      {steps: steps3} = feature3

      run1.runWithIt ce ->
        assert.equal steps1.GIVEN['a condition ${condition}'].callCount, 1
        assert.equal steps2.WHEN['something is done ${action}'].callCount, 1
        assert.equal steps3.THEN['something should have happened'].callCount, 1
        run1.runWithIt ce ->
          assert.equal steps1.GIVEN['a condition ${condition}'].callCount, 2
          assert.equal steps2.WHEN['something is done ${action}'].callCount, 2
          assert.equal steps3.THEN['something should have happened'].callCount, 2
          run1.runWithIt ce ->
            assert.equal steps1.GIVEN['a condition ${condition}'].callCount, 3
            assert.equal steps2.WHEN['something is done ${action}'].callCount, 3
            assert.equal steps3.THEN['something should have happened'].callCount, 3

            done()

    it 'should not execute promises more than once when features are reused in multiple scenarios', (done) ->
      ce = cbw done
      {feature1, feature2, feature3} = features()

      run1 = feature1.combine(feature2).combine(feature3)
      run2 = feature1.combine(feature2).combine(feature3)

      runX = run1.combine(run2)

      {steps: steps1} = feature1
      {steps: steps2} = feature2
      {steps: steps3} = feature3

      runX.runWithIt ce ->
        assert.equal steps1.GIVEN['a condition ${condition}'].callCount, 2
        assert.equal steps2.WHEN['something is done ${action}'].callCount, 2
        assert.equal steps3.THEN['something should have happened'].callCount, 2
        runX.runWithIt ce ->
          assert.equal steps1.GIVEN['a condition ${condition}'].callCount, 4
          assert.equal steps2.WHEN['something is done ${action}'].callCount, 4
          assert.equal steps3.THEN['something should have happened'].callCount, 4
          runX.runWithIt ce ->
            assert.equal steps1.GIVEN['a condition ${condition}'].callCount, 6
            assert.equal steps2.WHEN['something is done ${action}'].callCount, 6
            assert.equal steps3.THEN['something should have happened'].callCount, 6

            done()


  describe 'with context', ->
    feature = ->
      return declareStepsAndScenario
        steps:
          GIVEN: 'a condition ${condition}': ({@condition}) ->
          WHEN: 'something is done ${action}': ({@action}) ->
          THEN: 'I expect a result ${expectation}': ({@expectation}) ->
          THEN: 'expect context': ({context}) ->
            assert.deepEqual this, context

        scenario: (runner) ->
          runner
            .given 'a condition ${condition}', condition: 'one'
            .when 'something is done ${action}', action: 'two'
            .then 'I expect a result ${expectation}', expectation: 'three'
            .then 'expect context', context: {
              condition: 'one'
              action: 'two'
              expectation: 'three'
            }

    # TODO unfinished


  describe 'runner.run()', ->
    feature = ->
      return declareStepsAndScenario
        steps:
          GIVEN: 'a condition ${condition}': sinon.spy ({@condition}) ->

        scenario: (runner) ->
          runner
            .given 'a condition ${condition}', condition: 'one'

    it 'should run scenario without binding to `it`', (done) ->
      ce = cbw done

      ({steps} = feature()).run ce ->
        assert steps.GIVEN['a condition ${condition}'].calledOnce
        assert steps.GIVEN['a condition ${condition}'].calledWith condition: 'one'
        done()

    it 'should return a promise when no callback is given', (done) ->
      ce = cbw done

      ({steps} = feature()).run().then ->
        assert steps.GIVEN['a condition ${condition}'].calledOnce
        assert steps.GIVEN['a condition ${condition}'].calledWith condition: 'one'
        done()

  describe 'bdd.steps(steps)', ->
    steps =
      GIVEN: 'a condition ${condition}': sinon.spy ({@condition}) ->

    it 'should product the same result as bdd.accordingTo(-> steps).getRunner()', (done) ->
      ce = cbw done

      bdd.steps(steps)
        .given 'a condition ${condition}', condition: 'one'
        .run ce ->
          assert steps.GIVEN['a condition ${condition}'].calledOnce
          assert steps.GIVEN['a condition ${condition}'].calledWith condition: 'one'
          done()


createRunner = ->
  tests = []
  bddIt = sinon.spy (name, fn) ->
    tests.push fn

  runWithIt = ({runner}, cb) ->
    # Side effect: calls `it`, because `steps.done` is called inside scenario()
    runner.done it: bddIt

    async.series tests, cbw(cb) ->
      cb null, {bddIt, tests}

  run = ({runner}, cb) ->
    runner.run cb

  return {bddIt, tests, runWithIt, run}

buildTestRunner = ({runner, steps}) ->
  assert runner, 'Runner not defined'
  assert steps

  return {
    steps
    runner

    run: (cb) ->
      {run} = createRunner()

      run {runner}, cb

    runWithIt: (cb) ->
      {runWithIt} = createRunner()

      runWithIt {runner}, cb

    combine: (suffixRunners...) ->
      return buildTestRunner {steps, runner: bdd.combine(runner, suffixRunners.map((s) -> s.runner)...)}
  }

declareStepsAndScenario = ({steps, scenario}) ->
  assert steps
  assert scenario
  return buildTestRunner {steps, runner: scenario(bdd.accordingTo(-> steps).getRunner())}
