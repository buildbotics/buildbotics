DIR := $(shell dirname $(lastword $(MAKEFILE_LIST)))

NODE_MODS := $(DIR)/node_modules
JADE      := $(NODE_MODS)/jade/bin/jade.js
STYLUS    := $(NODE_MODS)/stylus/bin/stylus
AP        := $(NODE_MODS)/autoprefixer/autoprefixer
UGLIFY    := $(NODE_MODS)/uglify-js/bin/uglifyjs

HTTP_DIR := build/public/http

HTML   := index notfound
HTML   := $(patsubst %,$(HTTP_DIR)/%.html,$(HTML))
CSS    := $(wildcard src/stylus/*.styl)
CSS    := $(patsubst src/stylus/%.styl,$(HTTP_DIR)/css/%.css,$(CSS))
JS     := $(wildcard src/js/*.js)
JS_ASSETS := $(HTTP_DIR)/js/assets.js
STATIC := $(shell find src/resources -type f \! -name *~)
STATIC := $(patsubst src/resources/%,$(HTTP_DIR)/%,$(STATIC))
TEMPLS := $(wildcard src/jade/templates/*.jade)

WATCH  := src/jade src/js src/resources src/stylus Makefile

all: build node_modules

build: dirs html css js static
	@ln -sf $(HTTP_DIR) .

html: templates $(HTML)

css: $(CSS)

js: $(JS_ASSETS)

static: $(STATIC)

templates: build/templates.jade

build/templates.jade: $(TEMPLS)
	cat $(TEMPLS) >$@

$(HTTP_DIR)/index.html: build/templates.jade

$(JS_ASSETS): $(JS)
	$(UGLIFY) $(JS) -o $@ --source-map $@.map --source-map-root /js/ \
	  --source-map-url $(shell basename $@).map -c -p 2
	install $(JS) $(HTTP_DIR)/js/

node_modules:
	npm install

$(HTTP_DIR)/js/%.js: src/js/%.js
	install -D $< $@

$(HTTP_DIR)/%: src/resources/%
	install -D $< $@

$(HTTP_DIR)/%.html: src/jade/%.jade $(wildcard src/jade/*.jade)
	$(JADE) $< -o $(HTTP_DIR) || (rm $@; exit 1)

$(HTTP_DIR)/css/%.css: src/stylus/%.styl
	$(STYLUS) -I styles < $< | $(AP) -b "> 1%" >$@ || (rm $@; exit 1)

dirs:
	@mkdir -p $(HTTP_DIR)/css
	@mkdir -p $(HTTP_DIR)/js

watch:
	@clear
	@while inotifywait -qr -e modify -e create -e delete \
	  --exclude .*~ --exclude \#.* $(WATCH); do \
	  clear; \
	  $(MAKE); \
	done

tidy:
	rm -f $(shell find "$(DIR)" -name \*~)

clean: tidy
	rm -rf build/public http

.PHONY: all install build html css static templates clean tidy
