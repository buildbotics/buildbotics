DIR := $(shell dirname $(lastword $(MAKEFILE_LIST)))

NODE_MODS := $(DIR)/node_modules
JADE      := $(DIR)/jade.js
STYLUS    := $(NODE_MODS)/stylus/bin/stylus
AP        := $(NODE_MODS)/autoprefixer/autoprefixer
MARKDOWN  := $(DIR)/markdown.js

HTML := $(patsubst views/%.jade,public/%.html,$(wildcard views/*.jade))
CSS := $(patsubst styles/%.styl,public/css/%.css,$(wildcard styles/*.styl))

all: build dev

install:
	npm install

run: build
	npm start

build: html css

html: $(HTML)

css: $(CSS)

dev: public/api.html public/css/api.css
	mkdir -p dev/css dev/js
	cp public/api.html dev/index.html
	cp public/css/api.css dev/css
	cp public/js/api.js dev/js

node_modules:
	npm install

public/%.html: views/%.jade $(wildcard views/include/*.jade) $(wildcard views/dialogs/*.jade) node_modules
	$(JADE) $< >$@ || rm $@

public/css/%.css: styles/%.styl public/css node_modules
	$(STYLUS) -I styles < $< | $(AP) -b "> 1%" >$@ || rm $@

public/css:
	mkdir -p $@

public/api.html: docs/api.md

tidy:
	rm -f $(shell find "$(DIR)" -name \*~)

clean: tidy
	rm -f $(HTML) $(CSS) $(DOCS)
	rm -rf dev

.PHONY: all install run build html css clean tidy
