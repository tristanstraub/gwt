VERSION=0.0.1

all: build

build:
	@./node_modules/coffee-script/bin/coffee \
		-c \
		-o lib src

clean:
	rm -rf lib
	mkdir lib

test:
	@./node_modules/mocha/bin/mocha \
		--require coffee-script/register \
		test/*.coffee

publish: test build
	tar -zcvf ./gwt-$(VERSION).tgz -C .. gwt/package.json gwt/lib
	npm publish ./gwt-$(VERSION).tgz

.PHONY: build clean test
