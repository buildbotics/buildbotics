// Fake data *******************************************************************
var projects = {
    'projectA':
    {title: 'A test project', owner: 'fred', likes: 5, comments: 2,
     userLikes: true, image: 'images/project1.jpg', license: 'GPL',
     url: 'http://example.com/this/is/a/long/url/no/i/mean/it/really',
     tags: ['cnc', 'laser', '3D printing', 'wooden', 'fun'],
     images: [{url: 'images/project1.jpg', caption: 'A caption'}]},

    'projectB':
    {title: 'Another project', owner: 'alice', likes: 5450, comments: 2344,
     image: 'images/project2.jpg', license: 'GPL'},

    'projectC':
    {title: 'Cool project', owner: 'bob', likes: 23, comments: 35,
     image: 'images/project3.jpg', license: 'GPL'},

    'projectD':
    {title: 'Another project', owner: 'alice', likes: 5450, comments: 2344,
     image: 'images/project4.jpg', license: 'GPL'},

    'projectE':
    {title: 'Cool project', owner: 'bob', likes: 23, comments: 35,
     image: 'images/project5.jpg', license: 'GPL'},

    'projectF':
    {title: 'A test project', owner: 'fred', likes: 5, comments: 2,
     image: 'images/project6.jpg', license: 'GPL'}
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
        if (projects[project].owner == name)
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


// Modal Dialog ****************************************************************
function open_modal(cb) {
    $('#modal-overlay').on('click', function () {
        if (typeof cb != 'undefined') cb();
        close_modal();
        $scope.$apply();

    }).show()
}


function close_modal() {
    $('#modal-overlay').hide().unbind();
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
        $modal.open({
            templateUrl: 'register.html',
            controller: 'RegisterDialogCtrl',
            resolve: {
                name: function () {return name;},
                suggestions: function () {return suggestions;}
            }

        }).result.then(function (name) {
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
            if (typeof data.profile != 'undefined') {
                if (typeof data.profile.lastlog != 'undefined') {
                    $scope.user = data.profile;
                    $scope.authenticated = true;
                    return;

                } else if (typeof data.profile.name != 'undefined') {
                    // Authenticated but we need to register
                    $http.get('/api/name/suggestions')
                        .success(function (suggestions) {
                            // TODO check for errors
                            $scope.register(suggestions);

                        }).error(logged_out);

                    return;
                }
            }

            logged_out();
        });
    }

    load_user();
}


// Directives ******************************************************************
function username_directive($q, $http) {
    return {
        require: 'ngModel',
        link: function (scope, element, attrs, ctrl) {
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
    }
}


function bb_modal_directive() {
    return {
        restrict: 'E',
        transclude: true,
        templateUrl: 'modal.html',
        scope: {
            title: '@title',
            close: '&onClose'
        }
    }
}


function on_keypress_directive() {
    return function (scope, element, attrs) {
        function applyKeypress() {
            scope.$apply(attrs.onKeypress);
        };           
        
        var allowedKeys = scope.$eval(attrs.keys);

        element.bind('keyup', function(e) {
            // If no key restriction specified, always fire
            if (!allowedKeys || allowedKeys.length == 0) applyKeypress();
            else
                angular.forEach(allowedKeys, function(key) {
                    if (key == e.which) applyKeypress();
                })
        })
    }
}


function on_enter_directive() {
    return function (scope, element, attrs) {
        element.bind('keyup', function(e) {
            if (e.which == 13) scope.$apply(attrs.onEnter);
        })
    }
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
    $scope.edit = {};
    $scope.old = {};
    $scope.is_owner = true; // TODO
    $scope.licenses = [{name: 'GPL'}, {name: 'MIT'}]; // TODO

    $scope.edit = function (field, modal) {
        if (modal) open_modal(function () {$scope.save(field)});

        $scope.old[field] = $scope.project[field];
        $scope.edit[field] = true;
    };

    $scope.save = function (field) {
        $scope.edit[field] = false;
        close_modal();
    };

    $scope.cancel = function (field) {
        $scope.project[field] = $scope.old[field];
        $scope.edit[field] = false;
        close_modal();
    };
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
    deps = ['ngRoute', 'ngCookies', 'ui.bootstrap', 'ui.bootstrap.modal',
            'buildbotics.markdown'];
    angular
        .module('buildbotics', deps)
        .factory('httpRequestInterceptor', http_request_interceptor)
        .config(module_config)
        .directive('username', username_directive)
        .directive('bbModal', bb_modal_directive)
        .directive('onKeypress', on_keypress_directive)
        .directive('onEnter', on_enter_directive)
        .controller('BodyCtrl', body_controller)
        .controller('ContentCtrl', content_controller)
        .controller('RegisterDialogCtrl', register_dialog_controller)
        .controller('UserCtrl', user_controller)
        .controller('ProjectListCtrl',  project_list_controller)
        .controller('ProjectCtrl', project_controller);

    angular.bootstrap(document.documentElement, ['buildbotics']);
})
