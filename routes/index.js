var express = require('express');
var passport = require('passport');
var router = express.Router();
var config = require('../config');


// GET home page
router.get('/', function(req, res) {
    res.render('index', {
        title: 'Buildbotics',
        user: req.user ? req.user.displayName : 'Anonymous'
    });
});


// GET user data
router.get('/auth/user', function(req, res) {
    res.send(req.user);
});


// Auth
'google facebook twitter github'.split(' ').forEach(function (provider) {
    var data = config[provider].config;
    router.get('/auth/' + provider, passport.authenticate(provider, data));
    router.get('/auth/' + provider + '/callback',
               passport.authenticate(provider, {
                   successRedirect: '/',
                   failureRedirect: '/login'}));
});


router.get('/auth/logout', function(req, res) {
    req.logout();
    res.redirect('/');
});


function ensureAuthenticated(req, res, next) {
    if (req.isAuthenticated()) return next();
    res.redirect('/login');
}


module.exports = router;
