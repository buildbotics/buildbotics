function user_get_avatar(user) {
    if (user.provider == 'facebook')
        return 'http://graph.facebook.com/' +
        user.name.givenName + '.' + user.name.familyName +
        '/picture';

    user = user._json;
    if (user.picture) return user.picture;
    if (user.avatar_url) return user.avatar_url;
    if (user.profile_image_url) return user.profile_image_url;
}


// Main ************************************************************************
$(function() {
    // Tooltips
    $('a[title]').each(function () {
        $(this).attr({
            tooltip: $(this).attr('title'),
            'tooltip-placement': 'bottom',
            'tooltip-append-to-body': true,
            title: ''
        });
    });

    // Angular
    var app = angular.module('buildbotics', ['ngRoute', 'ui.bootstrap']);

    // Routing
    app.config(function($routeProvider, $locationProvider) {
        $routeProvider
            .when('/explore', {page: 'explore'})
            .when('/profile', {page: 'profile'})
            .when('/create', {page: 'create'})
            .when('/settings', {page: 'settings'})
            .otherwise({page: 'home'});

        $locationProvider.html5Mode(true);
    });

    // BodyCtrl
    app.controller(
        'BodyCtrl',
        function ($scope, $http) {
            $scope.authenticated = false;

            $http.get('/api/auth/user').success(function (user) {
                if (!user) return;
                $scope.user = user;
                $scope.avatar = user_get_avatar(user);
                $scope.authenticated = true;
            });
        });

    // ContentCtrl
    app.controller(
        'ContentCtrl',
        function ($scope, $route, $routeParams) {
            $scope.$on(
                "$routeChangeSuccess",
                function($currentRoute, $previousRoute) {
                    console.log($currentRoute);
                    $scope.page = $route.current.page;
                });
        });

    // ProjectListCtrl
    app.controller(
        'ProjectListCtrl',
        function ($scope) {
            $scope.projects = [
                {title: 'A test project', author: 'fred', name: 'projectA',
                 likes: 5, comments: 2, userLikes: true,
                 image: 'images/project1.jpg'},

                {title: 'Another project', author: 'alice', name: 'projectB',
                 likes: 5450, comments: 2344,
                 image: 'images/project2.jpg'},

                {title: 'Cool project', author: 'bob', name: 'projectC',
                 likes: 23, comments: 35,
                 image: 'images/project3.jpg'},

                {title: 'Another project', author: 'alice', name: 'projectB',
                 likes: 5450, comments: 2344,
                 image: 'images/project2.jpg'},

                {title: 'Cool project', author: 'bob', name: 'projectC',
                 likes: 23, comments: 35,
                 image: 'images/project3.jpg'},

                {title: 'A test project', author: 'fred', name: 'projectA',
                 likes: 5, comments: 2,
                 image: 'images/project1.jpg'},
            ];
        });

    // Bootstrap
    angular.bootstrap(document.documentElement, ['buildbotics']);

    $('#content').show();
})

