var config = require('./config');
var express = require('express');
var session = require('express-session')
var path = require('path');
var favicon = require('static-favicon');
var logger = require('morgan');
var cookieParser = require('cookie-parser');
var bodyParser = require('body-parser');
var passport = require('passport');
var GoogleStrategy = require('passport-google-oauth').OAuth2Strategy;
var riak = require('riak-js');
var RiakStore = require('connect-riak')(session);
var routes = require('./routes/index');

var app = express();

// Passport setup
passport.serializeUser(function(user, done) {
    done(null, user);
});

passport.deserializeUser(function(obj, done) {
    done(null, obj);
});

passport.use(new GoogleStrategy({
    clientID: config.google.client_id,
    clientSecret: config.google.client_secret,
    callbackURL: config.base_url + '/auth/google/callback'

}, function(accessToken, refreshToken, profile, done) {
    process.nextTick(function () {return done(null, profile);});
}));


// View engine setup
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'jade');

// DB
var db = riak.getClient({port: 8098, debug: app.get('env') === 'development'});

// Config
app.use(favicon());
app.use(logger('dev'));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded());
app.use(cookieParser());
app.use(session({secret: 'keyboard cat', store: new RiakStore({client: db})}));
app.use(passport.initialize());
app.use(passport.session());
app.use(require('stylus').middleware(path.join(__dirname, 'public')));
app.use(express.static(path.join(__dirname, 'public')));

app.use('/', routes);


/// Catch 404 and forwarding to error handler
app.use(function(req, res, next) {
    var err = new Error('Not Found');
    err.status = 404;
    next(err);
});


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
