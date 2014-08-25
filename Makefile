DIR := $(shell dirname $(lastword $(MAKEFILE_LIST)))

JADE := $(DIR)/node_modules/jade/bin/jade.js
STYLUS := $(DIR)/node_modules/stylus/bin/stylus

HTML := $(patsubst views/%.jade,static/%.html,$(wildcard views/*.jade))
CSS := $(patsubst styles/%.styl,static/css/%.css,$(wildcard styles/*.styl))

all: build

install:
	npm install

run: build
	npm start

build: html css

html: node_modules $(HTML)

css: node_modules $(CSS)

node_modules:
	npm install

static/%.html: views/%.jade $(wildcard views/include/*.jade)
	$(JADE) -o static $<

static/css/%.css: styles/%.styl
	$(STYLUS) -o static/css $<

tidy:
	rm -f $(shell find "$(DIR)" -name \*~)

clean: tidy
	rm $(HTML) $(CSS)

.PHONY: all install run build html css clean tidy
