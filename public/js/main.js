// Fake data *******************************************************************
var projects = {
    'projectA':
    {title: 'A test project', author: 'fred', likes: 5, comments: 2,
     userLikes: true, image: 'images/project1.jpg'},

    'projectB':
    {title: 'Another project', author: 'alice', likes: 5450, comments: 2344,
     image: 'images/project2.jpg'},

    'projectC':
    {title: 'Cool project', author: 'bob', likes: 23, comments: 35,
     image: 'images/project3.jpg'},

    'projectD':
    {title: 'Another project', author: 'alice', likes: 5450, comments: 2344,
     image: 'images/project4.jpg'},

    'projectE':
    {title: 'Cool project', author: 'bob', likes: 23, comments: 35,
     image: 'images/project5.jpg'},

    'projectF':
    {title: 'A test project', author: 'fred', likes: 5, comments: 2,
     image: 'images/project6.jpg'}
};


var users = {
    'fred': {
        'avatar':
        'http://png-1.findicons.com/files/icons/1072/face_avatars/300/g01.png'
    },
    'alice': {
        'displayName': 'Alice Andrews',
        'avatar':
        'http://png-5.findicons.com/files/icons/1072/face_avatars/300/fd01.png'
    },
    'bob': {
        'avatar':
        'https://cdn1.iconfinder.com/data/icons/brown-monsters/1024/' +
            'Brown_Monsters_16-01.png'
    }
};


// Accessors *******************************************************************
function project_get(user, name) {
    var project = projects[name];
    if (typeof project != 'undefined') project.name = name;
    return project;
}


function user_get(name) {
    var user = users[name];
    if (typeof user != 'undefined') user.name = name;
    return user;
}

function user_get_projects(name) {
    var user_projects = {};

    for (var project in projects)
        if (projects[project].author == name)
            user_projects[project] = projects[project];

    return user_projects;
}


function user_toggle_like(project) {
    project.userLikes = !project.userLikes;
    if (project.userLikes) project.likes++;
    else project.likes--;
}


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
    $.each(projects, function (name, project) {
        project.toggleLike = function () {
            user_toggle_like(project);
        }
    });

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
    var app = angular
        .module('buildbotics', ['ngRoute', 'ngCookies', 'ui.bootstrap'])
        .factory('httpRequestInterceptor', function ($cookies) {
            return {
                request: function ($config) {
                    var sid = $cookies['buildbotics.sid'];
                    if (sid) {
                        var auth = 'Token ' + sid.substr(0, 32);
                        $config.headers['Authorization'] = auth;
                    }

                    return $config;
                }
            };
        });

    // Routing
    app.config(function($routeProvider, $locationProvider, $httpProvider) {
        $routeProvider
            .when('/', {page: 'home'})
            .when('/explore', {page: 'explore'})
            .when('/create', {page: 'create'})
            .when('/build', {page: 'build'})
            .when('/settings', {page: 'settings'})
            .when('/:user', {page: 'user'})
            .when('/:user/:project', {page: 'project'})
            .otherwise({page: '404'});

        $locationProvider.html5Mode(true);

        $httpProvider.interceptors.push('httpRequestInterceptor');
    });

    // Body
    app.controller(
        'BodyCtrl',
        function ($scope, $http) {
            $scope.users = users;
            $scope.authenticated = false;

            function load_user() {
                $http.get('/api/auth/user').success(function (user) {
                    if (!user || user == 'null') return;
                    $scope.user = user;
                    $scope.authenticated = true;
                });
            }

            $scope.logout = function ($event) {
                $http.get('/api/auth/logout').success(function () {
                    $scope.user = undefined;
                    $scope.authenticated = false;
                });
            }

            load_user();
        });

    // Content
    app.controller(
        'ContentCtrl',
        function ($scope, $route, $routeParams, $location) {
            $scope.$on(
                "$routeChangeSuccess",
                function($currentRoute, $previousRoute) {
                    if ($location.path().indexOf('/api/auth') == 0)
                        window.location.href = $location.path();

                    else {
                        console.log($currentRoute);
                        $scope.page = $route.current.page;

                        var user = $routeParams.user;
                        var project = $routeParams.project;

                        if (typeof user != 'undefined') {
                            $scope.user = user_get(user);
                            if (typeof $scope.user == 'undefined')
                                $scope.page = '404';

                            else if (typeof project != 'undefined') {
                                $scope.project = project_get(user, project);
                                if (typeof $scope.project == 'undefined')
                                    $scope.page = '404';
                            }
                        }
                    }
                });
        });

    // User
    app.controller(
        'UserCtrl',
        function ($scope, $routeParams) {
            $scope.projects = user_get_projects($routeParams.user);
        })

    // Project List
    app.controller(
        'ProjectListCtrl',
        function ($scope, $routeParams) {
            if ($routeParams.user)
                $scope.projects = user_get_projects($routeParams.user);
            else $scope.projects = projects;
        });

    // Project
    app.controller(
        'ProjectCtrl',
        function ($scope, $routeParams) {
        });

    // Bootstrap
    angular.bootstrap(document.documentElement, ['buildbotics']);
})
