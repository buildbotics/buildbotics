var config = require('./config');
var express = require('express');
var session = require('express-session')
var favicon = require('static-favicon');
var logger = require('morgan');
var cookieParser = require('cookie-parser');
var bodyParser = require('body-parser');
var passport = require('passport');
var FacebookStrategy = require('passport-facebook').Strategy;
var TwitterStrategy  = require('passport-twitter').Strategy;
var GitHubStrategy  = require('passport-github').Strategy;
var GoogleStrategy = require('passport-google-oauth').OAuth2Strategy;
var riak = require('riak-js');
var RiakStore = require('connect-riak')(session);
var routes = require('./routes');

var app = express();

// Passport setup
// TODO store user in DB
passport.serializeUser(function(user, done) {done(null, user);});
passport.deserializeUser(function(obj, done) {done(null, obj);});

function auth_user(accessToken, refreshToken, profile, done) {
    console.log(profile);
    process.nextTick(function () {return done(null, profile);});
}

passport.use(new FacebookStrategy({
    clientID: config.facebook.clientID,
    clientSecret: config.facebook.clientSecret,
    callbackURL: config.base_url + '/api/auth/facebook/callback'
}, auth_user));

passport.use(new TwitterStrategy({
    consumerKey: config.twitter.consumerKey,
    consumerSecret: config.twitter.consumerSecret,
    callbackURL: config.base_url + '/api/auth/twitter/callback'
}, auth_user));

passport.use(new GitHubStrategy({
    clientID: config.github.clientID,
    clientSecret: config.github.clientSecret,
    callbackURL: config.base_url + '/api/auth/github/callback'
}, auth_user));

passport.use(new GoogleStrategy({
    clientID: config.google.clientID,
    clientSecret: config.google.clientSecret,
    callbackURL: config.base_url + '/api/auth/google/callback'
}, auth_user));


// DB
var db = riak.getClient({
    port: 8098,
    debug: app.get('env') === 'development'
});

// Config
app.use(favicon());
app.use(logger('dev'));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded());
app.use(cookieParser());
app.use(session({secret: 'keyboard cat', store: new RiakStore({client: db})}));
app.use(passport.initialize());
app.use(passport.session());

app.use(function (req, res, next) {
    req.db = db;
    next();
});
app.use('/api', routes);


/// Catch 404
app.use(function(req, res, next) {res.redirect('/notfound.html')})


// Error handlers
// Development error handler, will print stacktrace
if (app.get('env') === 'development') {
    app.use(function(err, req, res, next) {
        res.status(err.status || 500);
        res.render('error', {
            message: err.message,
            error: err
        });
    });
}


// Production error handler, no stacktraces leaked to user
app.use(function(err, req, res, next) {
    res.status(err.status || 500);
    res.render('error', {
        message: err.message,
        error: {}
    });
});


module.exports = app;
