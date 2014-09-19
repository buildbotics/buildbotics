DIR := $(shell dirname $(lastword $(MAKEFILE_LIST)))

NODE_MODS := $(DIR)/node_modules
JADE      := $(DIR)/jade.js
STYLUS    := $(NODE_MODS)/stylus/bin/stylus
AP        := $(NODE_MODS)/autoprefixer/autoprefixer
MARKDOWN  := $(DIR)/markdown.js

HTML := $(patsubst views/%.jade,public/%.html,$(wildcard views/*.jade))
CSS := $(patsubst styles/%.styl,public/css/%.css,$(wildcard styles/*.styl))
DOCS := $(patsubst docs/%.jade,public/docs/%.html,$(wildcard docs/*.jade))

all: build docs

install:
	npm install

run: build
	npm start

build: html css

html: $(HTML)

css: $(CSS)

docs: $(DOCS)

node_modules:
	npm install

public/%.html: views/%.jade $(wildcard views/include/*.jade) node_modules
	$(JADE) $< >$@

public/css/%.css: styles/%.styl public/css node_modules
	$(STYLUS) -I styles < $< | $(AP) -b "> 1%" >$@

public/css:
	mkdir -p $@

public/docs/%.html: docs/%.jade node_modules
	$(JADE) $< >$@

tidy:
	rm -f $(shell find "$(DIR)" -name \*~)

clean: tidy
	rm $(HTML) $(CSS) $(DOCS)

.PHONY: all install run build html css clean tidy docs
