<div id="table-of-contents">
<h2>Table of Contents</h2>
<div id="text-table-of-contents">
<ul>
<li><a href="#orgheadline22">1. Given, when, then V1.3.1-alpha</a>
<ul>
<li><a href="#orgheadline8">1.1. Declaring steps, building a test, and running the test</a>
<ul>
<li><a href="#orgheadline1">1.1.1. Steps declaration</a></li>
<li><a href="#orgheadline2">1.1.2. Building a test</a></li>
<li><a href="#orgheadline5">1.1.3. Running a test directly</a></li>
<li><a href="#orgheadline6">1.1.4. Running a test using mocha</a></li>
<li><a href="#orgheadline7">1.1.5. Override `it`</a></li>
</ul>
</li>
<li><a href="#orgheadline10">1.2. Context</a>
<ul>
<li><a href="#orgheadline9">1.2.1. Normal use of context, without lexical closures:</a></li>
</ul>
</li>
<li><a href="#orgheadline13">1.3. Asynchronous steps</a>
<ul>
<li><a href="#orgheadline11">1.3.1. Steps can return promises:</a></li>
<li><a href="#orgheadline12">1.3.2. Steps can use callbacks:</a></li>
</ul>
</li>
<li><a href="#orgheadline19">1.4. Results can be retrieved from and passed back into steps</a>
<ul>
<li><a href="#orgheadline14">1.4.1. Single results can be returned from and passed into steps</a></li>
<li><a href="#orgheadline15">1.4.2. Multiple results can be passed into steps</a></li>
<li><a href="#orgheadline16">1.4.3. Multiple results can be returned from steps</a></li>
<li><a href="#orgheadline17">1.4.4. Results can be permanently overriden with `set`</a></li>
<li><a href="#orgheadline18">1.4.5. Use `tap()` instead of `result.set`</a></li>
</ul>
</li>
<li><a href="#orgheadline20">1.5. Steps can be combined from multiple declarations using `gwt.combine(&#x2026;)`</a></li>
<li><a href="#orgheadline21">1.6. Insert a custom function call without a step declaration (debugging)</a></li>
</ul>
</li>
</ul>
</div>
</div>

# Given, when, then V1.3.1-alpha<a id="orgheadline22"></a>

Behaviour driven development for nodejs.

## Declaring steps, building a test, and running the test<a id="orgheadline8"></a>

### Steps declaration<a id="orgheadline1"></a>

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

### Building a test<a id="orgheadline2"></a>

The order of execution is declared using the dictionary of
steps. Steps can be used multiple times and in any order.

\`${&#x2026;}\` strings are placeholders for values passed into steps. They
are used to generate descriptions for \`it\` blocks.

    myTest = steps
      .given 'elevator with open doors and ${n} buttons', {n: 10}
      .when 'button ${i} is pressed', {i: 4}
      .then 'the button light ${i} goes on', {i: 4}

### Running a test directly<a id="orgheadline5"></a>

1.  Using a callback

        myTest.run (err) -> ...

2.  Returning a promise

        myTest.run()
          .then -> ...
          .fail (err) -> ...

### Running a test using mocha<a id="orgheadline6"></a>

    # `done()` registers with `it`
    myTest.done()

### Override \`it\`<a id="orgheadline7"></a>

    # `done()` registers with `it`
    myTest.done(it: (description, testFn) -> ...)

## Context<a id="orgheadline10"></a>

Each step has access to a context object, via \`this\`, which is shared
between all steps attached to a runner.

### Normal use of context, without lexical closures:<a id="orgheadline9"></a>

    steps = gwt.steps
      GIVEN: 'a given': ->
        @bar = 'x'
    
      WHEN: 'an action is taken': ->
        assert.equal @bar, 'x', 'Context not shared' # -> PASS
    
    steps
      .given 'a given'
      .when 'an action is taken'
      .run (err) -> ...

## Asynchronous steps<a id="orgheadline13"></a>

### Steps can return promises:<a id="orgheadline11"></a>

If the return value of a step is a promise, it will
be used to chain onto the following steps.

    Q = require 'q'
    steps = gwt.steps
      GIVEN: 'a precondition': ->
        deferred = Q.defer()
        setTimeout (-> deferred.resolve()), 1000
        return deferred.promise
    
    steps.run()

### Steps can use callbacks:<a id="orgheadline12"></a>

If the return value of a step is a function, it is assumed
to be an asynchronous function and called with a callback which
will resume execution of following steps when it is called.

    steps = gwt.steps
      GIVEN: 'a precondition': -> (cb) ->
        setTimeout (-> cb()), 1000
    
    steps.run()

## Results can be retrieved from and passed back into steps<a id="orgheadline19"></a>

\`gwt.result()\` produces a placeholder that carries information via
the context across steps, but provides us with an external reference.

### Single results can be returned from and passed into steps<a id="orgheadline14"></a>

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

### Multiple results can be passed into steps<a id="orgheadline15"></a>

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

### Multiple results can be returned from steps<a id="orgheadline16"></a>

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

### Results can be permanently overriden with \`set\`<a id="orgheadline17"></a>

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

### Use \`tap()\` instead of \`result.set\`<a id="orgheadline18"></a>

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

## Steps can be combined from multiple declarations using \`gwt.combine(&#x2026;)\`<a id="orgheadline20"></a>

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

## Insert a custom function call without a step declaration (debugging)<a id="orgheadline21"></a>

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
