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


// App Config ******************************************************************
function http_request_interceptor($cookies) {
    return {
        request: function ($config) {
            var sid = $cookies['buildbotics.sid'];
            console.log($config.url + ': ' + sid);

            if (sid) {
                var auth = 'Token ' + sid.substr(0, 32);
                $config.headers['Authorization'] = auth;
            }

            return $config;
        }
    };
}


function module_config($routeProvider, $locationProvider, $httpProvider) {
    $routeProvider
        .when('/_=_', {redirectTo: '/'}) // Fix facebook URL hash cruft
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
}


// Body Controller *************************************************************
function body_controller($scope, $http, $modal, $cookies) {
    $scope.users = users;
    $scope.authenticated = false;

    function logged_out() {
        delete $cookies['buildbotics.sid'];
        $scope.user = undefined;
        $scope.authenticated = false;
    }

    $scope.logout = function ($event) {
        $http.get('/api/auth/logout').success(logged_out);
    }

    $scope.register = function (suggestions) {
        var modalInstance = $modal.open({
            templateUrl: 'register.html',
            controller: 'RegisterDialogCtrl',
            resolve: {
                name: function () {return name;},
                suggestions: function () {return suggestions;}
            }
        });

        modalInstance.result.then(function (name) {
            $http.put('/api/name/register/' + name)
                .success(function (data) {
                    if (data == 'ok') {
                        load_user();
                        // TODO Go to profile view

                    } else logged_out();
                }).error(logged_out);
        }, logged_out);
    };


    function load_user() {
        $http.get('/api/auth/user').success(function (data) {
            if (typeof data.joined != 'undefined') {
                $scope.user = data;
                $scope.authenticated = true;

            } else if (typeof data.name != 'undefined') {
                // Authenticated but we need to register

                // Suggest name
                if (data.name.match(/\W/) && data.email)
                    data.name = data.email.replace(/@.*/, '');

                data.name = data.name.toLowerCase().replace(/\W/g, '_');

                $http.get('/api/name/suggestions')
                    .success(function (suggestions) {
                        // TODO check for errors
                        $scope.register(suggestions);

                    }).error(logged_out);
            } else logged_out();
        });
    }

    load_user();
}


function username_directive($q, $http) {
    return {
        require: 'ngModel',
        link: function (scope, elm, attrs, ctrl) {
            ctrl.$asyncValidators.username = function (username) {
                if (ctrl.$isEmpty(username)) return $q.when(false);

                var def = $q.defer();

                $http.get('/api/name/available/' + username)
                    .success(function (result) {
                        if (result) def.resolve();
                        else def.reject();
                    }).error(function () {def.reject();});

                return def.promise;
            };
        }
    };
}


// Content Controller **********************************************************
function content_controller($scope, $route, $routeParams, $location) {
    $scope.$on(
        '$routeChangeSuccess',
        function ($currentRoute, $previousRoute) {
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
}


// Register Dialog Controller **************************************************
function register_dialog_controller($scope, $modalInstance, suggestions) {
    $scope.user = {};
    $scope.user.name = suggestions.length ? suggestions[0] : '';
    $scope.user.suggestions = suggestions;
    $scope.ok = function () {$modalInstance.close($scope.user.name);};
    $scope.cancel = function () {$modalInstance.dismiss('cancel');};

    $scope.hitEnter = function(e) {
        if (angular.equals(e.keyCode,13) &&
            !(angular.equals($scope.user.name, null) ||
              angular.equals($scope.user.name, '')))
            $scope.ok();
    };
}


// User Controller *************************************************************
function user_controller($scope, $routeParams) {
    $scope.projects = user_get_projects($routeParams.user);
}


// Project List Controller *****************************************************
function project_list_controller($scope, $routeParams) {
    if ($routeParams.user)
        $scope.projects = user_get_projects($routeParams.user);
    else $scope.projects = projects;
}


// Project Controller **********************************************************
function project_controller($scope, $routeParams) {
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

    // Angular setup
    deps = ['ngRoute', 'ngCookies', 'ui.bootstrap', 'ui.bootstrap.modal'];
    angular
        .module('buildbotics', deps)
        .factory('httpRequestInterceptor', http_request_interceptor)
        .config(module_config)
        .directive('username', username_directive)
        .controller('BodyCtrl', body_controller)
        .controller('ContentCtrl', content_controller)
        .controller('RegisterDialogCtrl', register_dialog_controller)
        .controller('UserCtrl', user_controller)
        .controller('ProjectListCtrl',  project_list_controller)
        .controller('ProjectCtrl', project_controller);

    angular.bootstrap(document.documentElement, ['buildbotics']);
})
