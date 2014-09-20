#!/usr/bin/env node
// Adds Markdown and Markdown TOC functions with syntax highlighting to Jade

var fs = require('fs');
var jade = require('jade');
var marked = require('marked');
var toc = require('marked-toc');
var highlight = require('highlight.js');


// Configure
marked.setOptions({
    highlight: function (code, lang) {
        if (lang == 'none') return code;
        if (lang) return highlight.highlight(lang, code).value;
        return highlight.highlightAuto(code).value;
    }
});

var toc_opts = {
    firsth1: true,
    maxDepth: 2
};


// Markdown for Jade
function read_file(filename) {
    return fs.readFileSync(filename, 'utf8');
}


function md_toc(filename) {
    return marked(toc(read_file(filename), toc_opts));
}


function md(filename) {
    return marked(read_file(filename));
}


// Read input
var args = process.argv.slice(2);
args.forEach(function (filename, index, array) {
    var data = read_file(filename);

    var jade_opts = {
        filename: filename,
        md_toc: md_toc,
        md: md
    };

    process.stdout.write(jade.render(data, jade_opts));
});
