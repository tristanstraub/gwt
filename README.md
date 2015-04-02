<div id="table-of-contents">
<h2>Table of Contents</h2>
<div id="text-table-of-contents">
<ul>
<li><a href="#sec-1">1. Given, when, then</a>
<ul>
<li><a href="#sec-1-1">1.1. Declaring steps, building a test, and running the test</a>
<ul>
<li><a href="#sec-1-1-1">1.1.1. Steps declaration</a></li>
<li><a href="#sec-1-1-2">1.1.2. Building a test</a></li>
<li><a href="#sec-1-1-3">1.1.3. Running a test directly</a></li>
<li><a href="#sec-1-1-4">1.1.4. Running a test using mocha</a></li>
<li><a href="#sec-1-1-5">1.1.5. Override `it`</a></li>
</ul>
</li>
<li><a href="#sec-1-2">1.2. Context</a>
<ul>
<li><a href="#sec-1-2-1">1.2.1. Normal use of context, without lexical closures:</a></li>
<li><a href="#sec-1-2-2">1.2.2. Writing to a previous context object does not carry over to the rest:</a></li>
<li><a href="#sec-1-2-3">1.2.3. Using `getContext` from within closures to retrieve the current context</a></li>
</ul>
</li>
<li><a href="#sec-1-3">1.3. Asynchronous steps</a>
<ul>
<li><a href="#sec-1-3-1">1.3.1. Steps can return promises:</a></li>
<li><a href="#sec-1-3-2">1.3.2. Steps can use callbacks:</a></li>
</ul>
</li>
<li><a href="#sec-1-4">1.4. Results can be retrieved from and passed back into steps</a>
<ul>
<li><a href="#sec-1-4-1">1.4.1. Single results can be returned from and passed into steps</a></li>
<li><a href="#sec-1-4-2">1.4.2. Multiple results can be passed into steps</a></li>
<li><a href="#sec-1-4-3">1.4.3. Multiple results can be returned from steps</a></li>
<li><a href="#sec-1-4-4">1.4.4. Results can be permanently overriden with `set`</a></li>
<li><a href="#sec-1-4-5">1.4.5. Use `tap()` instead of `result.set`</a></li>
</ul>
</li>
<li><a href="#sec-1-5">1.5. Steps can be combined from multiple declarations using `gwt.combine(&#x2026;)`</a></li>
<li><a href="#sec-1-6">1.6. Insert a custom function call without a step declaration (debugging)</a></li>
</ul>
</li>
</ul>
</div>
</div>

# Given, when, then<a id="sec-1" name="sec-1"></a>

Behaviour driven development for nodejs.

## Declaring steps, building a test, and running the test<a id="sec-1-1" name="sec-1-1"></a>

### Steps declaration<a id="sec-1-1-1" name="sec-1-1-1"></a>

The available dictionary of steps has to be created before
the order of execution of these steps is declared:

    assert = require 'assert'
    gwt = require 'gwt'
    steps = gwt.steps
      GIVEN:
        'an elevator with open doors and ${n} buttons': ({n}) ->
          @buttons = new Array(n)
          @lights = new Array(n)
      WHEN:
        'button ${i} is pressed': ({i}) ->
          @button[i].press()
      THEN:
        'the button light ${i} goes on': ->
          assert @lights[i].pressed

See how \`this\` is bound to a context object that is passed between
each given/when/then step. Store shared data against \`this\`.

NOTE: context is a new object in each step, with each key/value pair copied
across to the new context, which is provided to the subsequent
step. (See below)

### Building a test<a id="sec-1-1-2" name="sec-1-1-2"></a>

The order of execution is declared using the dictionary of
steps. Steps can be used multiple times and in any order.

\`${&#x2026;}\` strings are placeholders for values passed into steps. They
are used to generate descriptions for \`it\` blocks.

    myTest = steps
      .given 'elevator with open doors and ${n} buttons', {n: 10}
      .when 'button ${i} is pressed', {i: 4}
      .then 'the button light ${i} goes on', {i: 4}

### Running a test directly<a id="sec-1-1-3" name="sec-1-1-3"></a>

1.  Using a callback

        myTest.run (err) -> ...

2.  Returning a promise

        myTest.run()
          .then -> ...
          .fail (err) -> ...

### Running a test using mocha<a id="sec-1-1-4" name="sec-1-1-4"></a>

    # `done()` registers with `it`
    myTest.done()

### Override \`it\`<a id="sec-1-1-5" name="sec-1-1-5"></a>

    # `done()` registers with `it`
    myTest.done(it: (description, testFn) -> ...)

## Context<a id="sec-1-2" name="sec-1-2"></a>

Each step has access to a context object, via \`this\`, which is copied
from step to step.

CAVEAT: Each step has its own context object, with values from
previous contexts copied across. This creates unexpected behaviour
when trying to set values inside the context from inside a closure.

If you create a function within a step, and call it later, its lexical scope points to an old context.
You can retrieve the latest context through the function \`getContext\`
held within each context object.

### Normal use of context, without lexical closures:<a id="sec-1-2-1" name="sec-1-2-1"></a>

    steps = gwt.steps
      GIVEN: 'a given': ->
        @bar = 'x'

      WHEN: 'an action is taken': ->
        assert.equal @bar, 'x', 'Set in the wrong context' # -> PASS

    steps
      .given 'a given'
      .when 'an action is taken'
      .run (err) -> ...

### Writing to a previous context object does not carry over to the rest:<a id="sec-1-2-2" name="sec-1-2-2"></a>

    steps = gwt.steps
      GIVEN: 'a given': ->
        context = this
        @setBar = ->
          context.bar = 'x'

      WHEN: 'an action is taken': ->
        @setBar()
        assert.equal @bar, 'x', 'Set in the wrong context' # -> ERROR

    steps
      .given 'a given'
      .when 'an action is taken'
      .run (err) -> ...

### Using \`getContext\` from within closures to retrieve the current context<a id="sec-1-2-3" name="sec-1-2-3"></a>

To get this to work, use getContext, which returns the current
context.

    steps = gwt.steps
      GIVEN: 'a given': ->
        context = this
        @setBar = ->
          context.getContext().bar = 'x'

      WHEN: 'an action is taken': ->
        @setBar()
        assert.equal @bar, 'x', 'Set in the wrong context' # -> PASS

    steps
      .given 'a given'
      .when 'an action is taken'
      .run (err) -> ...

## Asynchronous steps<a id="sec-1-3" name="sec-1-3"></a>

### Steps can return promises:<a id="sec-1-3-1" name="sec-1-3-1"></a>

If the return value of a step is a promise, it will
be used to chain onto the following steps.

    Q = require 'q'
    steps = gwt.steps
      GIVEN: 'a precondition': ->
        deferred = Q.defer()
        setTimeout (-> deferred.resolve()), 1000
        return deferred.promise

    steps.run()

### Steps can use callbacks:<a id="sec-1-3-2" name="sec-1-3-2"></a>

If the return value of a step is a function, it is assumed
to be an asynchronous function and called with a callback which
will resume execution of following steps when it is called.

    steps = gwt.steps
      GIVEN: 'a precondition': -> (cb) ->
        setTimeout (-> cb()), 1000

    steps.run()

## Results can be retrieved from and passed back into steps<a id="sec-1-4" name="sec-1-4"></a>

\`gwt.result()\` produces a placeholder that carries information via
the context across steps, but provides us with an external reference.

### Single results can be returned from and passed into steps<a id="sec-1-4-1" name="sec-1-4-1"></a>

    baz  = gwt.result()

    steps = gwt.steps
      WHEN: 'baz is created': ->
        return baz: 'xyz'

      THEN: 'baz can be used': ({baz}) ->
        assert.deepEqual baz, baz: 'xyz'

    steps
      .when('baz is created').resultTo(baz)
      .then('baz can be used', {baz})
      .run (err) ->

### Multiple results can be passed into steps<a id="sec-1-4-2" name="sec-1-4-2"></a>

    baz = gwt.result()
    foo = gwt.result()

    steps = gwt.steps
      WHEN:
        'baz is created': ->
          return 'xyz'

        'foo is created': -> (cb) ->
          cb null, 'foo'

      THEN: 'results can be used': ({baz, foo}) ->
        assert.equal baz, 'xyz'
        assert.equal foo, 'foo'

    steps
      .when('baz is created').resultTo(baz)
      .then('results can be used', {baz, foo})
      .run (err) -> ...

### Multiple results can be returned from steps<a id="sec-1-4-3" name="sec-1-4-3"></a>

    baz = gwt.result()
    foo = gwt.result()

    steps = gwt.steps
      WHEN:
        'foo and baz are created': ->
          return foo: 'foo', baz: 'xyz'

      THEN: 'results can be used': ({baz, foo}) ->
        assert.equal baz, 'xyz'
        assert.equal foo, 'foo'

    steps
      .when('foo and baz are created').resultTo({baz, foo})
      .then('results can be used', {baz, foo})
      .run (err) -> ...

### Results can be permanently overriden with \`set\`<a id="sec-1-4-4" name="sec-1-4-4"></a>

If you call \`result.set\` with a value, any time it is passed
to a step, it will be substituted with the given value.

You can call \`set\` inside or outside a step.

    value = gwt.result()
    value.set 'xyz'

    steps = gwt.steps
      THEN: 'result can be used': ({value}) ->
        assert.equal baz, 'xyz'

    steps
      .then('result can be used', {value})
      .run (err) -> ...

### Use \`tap()\` instead of \`result.set\`<a id="sec-1-4-5" name="sec-1-4-5"></a>

Using \`tap()\` provides a less permanent way of setting a result
placeholder value.

    baz = gwt.result()

    steps = gwt.steps
      THEN:
        'baz has been set': ({baz}) ->
          assert.equal baz, 'xyz'

    steps
      .tap(({baz} -> return 'xyz'), {baz})
      .then 'baz has been set', {baz}
      .run (err) -> ...

## Steps can be combined from multiple declarations using \`gwt.combine(&#x2026;)\`<a id="sec-1-5" name="sec-1-5"></a>

Calls to \`gwt.steps(&#x2026;).given().when().then()\` produce a runner,
which
can be combined with other runners using \`gwt.combine(runner1,
runner2, &#x2026;)\` to produce another runner, so that any level of nesting
is possible.

NOTE: Context does not get copied between combined runners. However,
result placeholders do carry values across combined runners.

    steps1 = gwt.steps
      GIVEN: 'one': ->
      THEN: 'two': ->

    steps2 = gwt.steps
      GIVEN: 'three': ->
      WHEN: 'four': ->
      THEN: 'five': ->

    gwt.combine(
      steps1
        .given 'one'
        .then 'two'

      steps2
        .given 'three'
        .when 'four'
        .then 'five'
    ).run (err) -> ...

## Insert a custom function call without a step declaration (debugging)<a id="sec-1-6" name="sec-1-6"></a>

You can access context and result values by providing a function
instead of a description to the \`steps.tap()\` function

    baz = gwt.result()

    steps = gwt.steps
      WHEN:
        'baz is created': ->
          return 'xyz'

    steps
      .when('baz is created').resultTo(baz)
      .tap(({baz} -> console.log baz), {baz})
      .run (err) -> ...
