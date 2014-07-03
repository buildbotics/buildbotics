var express = require('express');
var passport = require('passport');
var router = express.Router();


// GET home page
router.get('/', function(req, res) {
    res.render('index', {
        title: 'Buildbotics',
        user: req.user ? req.user.displayName : 'Anonymous'
    });
});


// Auth
router.get('/auth/google',
        passport.authenticate('google', {
            scope: ['https://www.googleapis.com/auth/userinfo.profile',
                    'https://www.googleapis.com/auth/userinfo.email']}),
        function(req, res) {
            // The request will be redirected to Google for authentication,
            // so this function will not be called.
        });


router.get('/auth/google/callback',
           passport.authenticate('google', {failureRedirect: '/login'}),
           function(req, res) {res.redirect('/');}
          );


router.get('/logout', function(req, res) {
    req.logout();
    res.redirect('/');
});


function ensureAuthenticated(req, res, next) {
    if (req.isAuthenticated()) {return next();}
    res.redirect('/login');
}


module.exports = router;
