DIR := $(shell dirname $(lastword $(MAKEFILE_LIST)))

NODE_MODS := $(DIR)/node_modules
JADE      := $(DIR)/scripts/jade.js
STYLUS    := $(NODE_MODS)/stylus/bin/stylus
AP        := $(NODE_MODS)/autoprefixer/autoprefixer

HTTP_DIR := build/public/http

HTML   := api index notfound
HTML   := $(patsubst %,$(HTTP_DIR)/%.html,$(HTML))
CSS    := $(wildcard src/stylus/*.styl)
CSS    := $(patsubst src/stylus/%.styl,$(HTTP_DIR)/css/%.css,$(CSS))
JS     := $(wildcard src/js/*.js)
JS     := $(patsubst src/js/%.js,$(HTTP_DIR)/js/%.js,$(JS))
STATIC := $(shell find src/resources -type f \! -name *~)
STATIC := $(patsubst src/resources/%,$(HTTP_DIR)/%,$(STATIC))

all: build api node_modules

build: dirs html css js static
	@ln -sf $(HTTP_DIR) .

html: $(HTML)

css: $(CSS)

js: $(JS)

static: $(STATIC)

api: $(HTTP_DIR)/api.html $(HTTP_DIR)/css/api.css
	@mkdir -p api/css api/js
	@cp $(HTTP_DIR)/api.html api/index.html
	@cp $(HTTP_DIR)/css/api.css api/css
	@cp $(HTTP_DIR)/js/api.js api/js

node_modules:
	npm install

$(HTTP_DIR)/js/%.js: src/js/%.js
	install -D $< $@

$(HTTP_DIR)/%: src/resources/%
	install -D $< $@

$(HTTP_DIR)/%.html: src/jade/%.jade $(wildcard src/jade/*.jade)
	$(JADE) $< >$@ || rm $@

$(HTTP_DIR)/css/%.css: src/stylus/%.styl
	$(STYLUS) -I styles < $< | $(AP) -b "> 1%" >$@ || rm $@

dirs:
	@mkdir -p $(HTTP_DIR)/css

$(HTTP_DIR)/api.html: docs/api.md

tidy:
	rm -f $(shell find "$(DIR)" -name \*~)

clean: tidy
	rm -rf api build/public http

.PHONY: all install build html css static api clean tidy
