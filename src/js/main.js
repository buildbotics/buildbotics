// App Config ******************************************************************
function route_get_profile($buildbotics, $route) {
    var profile = $route.current.params.profile;

    return $buildbotics.get('/api/profiles/' + profile)
        .success(function (data) {return data;});
}


function route_get_thing($buildbotics, $route) {
    var profile = $route.current.params.profile;
    var thing = $route.current.params.thing;

    return $buildbotics.get('/api/profiles/' + profile + '/things/' + thing)
        .success(function (data) {return data;});
}


function module_config($routeProvider, $locationProvider) {
    $routeProvider
        .when('/_=_', {redirectTo: '/'}) // Fix facebook URL hash cruft
        .when('/', {page: 'home'})
        .when('/explore', {page: 'explore'})
        .when('/create', {page: 'create'})
        .when('/build', {page: 'build'})
        .when('/settings', {page: 'settings'})
        .when('/:profile', {
            page: 'profile',
            resolve: {profile: route_get_profile}
        })
        .when('/:profile/:thing', {
            page: 'thing',
            resolve: {thing: route_get_thing}
        })
        .otherwise({page: '404'});

    $locationProvider.html5Mode(true);
}


// Body Controller *************************************************************
function body_controller($scope, $buildbotics, $modal) {
    $buildbotics.extend($scope);

    $scope.register = function (suggestions) {
        $modal.open({
            templateUrl: 'register.html',
            controller: 'RegisterDialogCtrl',
            resolve: {
                name: function () {return name;},
                suggestions: function () {return suggestions;}
            }

        }).result.then(function (name) {
            $buildbotics.put('/api/profiles/' + name + '/register')
                .success(function (data) {
                    if (data == 'ok') {
                        load_user();
                        // TODO Go to profile view

                    } else $buildbotics.logged_out();
                }).error($buildbotics.logged_out);
        }, $buildbotics.logged_out);
    };


    function load_user() {
        $buildbotics.get('/api/auth/user').success(function (data) {
            if (typeof data.profile != 'undefined') {
                if (typeof data.profile.lastlog != 'undefined') {
                    $buildbotics.logged_in(data.profile);
                    return;

                } else if (typeof data.profile.name != 'undefined') {
                    // Authenticated but we need to register
                    $buildbotics.get('/api/suggest')
                        .success(function (suggestions) {
                            // TODO check for errors
                            $scope.register(suggestions);

                        }).error($buildbotics.logged_out);

                    return;
                }
            }

            $buildbotics.logged_out();
        });
    }

    load_user();
}


// Content Controller **********************************************************
function content_controller($scope, $route, $routeParams, $location, $cookies) {
    $scope.$on(
        '$routeChangeSuccess',
        function (event, current, previous, rejection) {
            if ($location.path().indexOf('/api/auth') == 0) {
                // Do real redirect for login
                window.location.href = $location.path();

            } else {
                console.log('page: ' + $route.current.page);
                $scope.page = $route.current.page;

                if ($route.current.locals.profile)
                    $scope.profile_data = $route.current.locals.profile.data;

                if ($route.current.locals.thing) {
                    $scope.thing_data = $route.current.locals.thing.data;

                    // Separate files from images
                    var both = $scope.thing_data.files;
                    var files = [];
                    var images = [];
                    for (var i = 0; i < both.length; i++) {
                        both[i].name = both[i].file;

                        if (both[i].display) images.push(both[i]);
                        else files.push(both[i]);
                    }

                    $scope.thing_data.files = files;
                    $scope.thing_data.images = images;
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


// Profile Controller **********************************************************
function profile_controller($scope) {
    $scope.profile = $scope.profile_data.profile;
    $scope.things = $scope.profile_data.things;
    console.log($scope);
}


// Create Controller ***********************************************************
function create_controller($scope, $buildbotics, $location, $notify) {
    $buildbotics.extend($scope);
    $scope.thing = {name: '', title: ''};
    $scope.ok = function () {
        var url = '/api/profiles/' + $buildbotics.user.name + '/things/' +
            $scope.thing.name;

        var thing = '/' + $buildbotics.user.name + '/' + $scope.thing.name;

        $buildbotics.put(url, {type: 'thing', title: $scope.thing.title})
            .success(function (data) {
                if (data != 'ok')
                    $notify.error('Failed to create thing',
                                  'Failed to create ' + thing + '\n' +
                                  JSON.stringify(data));
                else $location.path(thing);

            }).error(function (data, status) {
                $notify.error('Failed to create thing',
                             'Failed to create ' + thing + '\n' + status);
            });
    };
}



function buildbotics_run($rootScope, $cookies, $window, $document, $location) {
    // Recover path after login
    $rootScope.$on(
        '$locationChangeStart',
        function (event, newUrl) {
            // Parse URL
            var a = document.createElement('a');
            a.href = newUrl;
            var path = a.pathname;

            if (path == '/' && $cookies['buildbotics.pre-login-path']) {
                // Restore location after login
                $location.path($cookies['buildbotics.pre-login-path']);
                delete $cookies['buildbotics.pre-login-path'];
                event.preventDefault();

            } else if (path.indexOf('/api/auth/') == 0)
                // Save location before login
                $cookies['buildbotics.pre-login-path'] =
                    $window.location.pathname;
        }
    )
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

    // Angular setup
    deps = ['ngRoute', 'ngCookies', 'ngTouch',
            'ui.bootstrap', 'ui.bootstrap.modal',
            'buildbotics.service', 'buildbotics.notify', 'buildbotics.things',
            'buildbotics.modal', 'buildbotics.markdown', 'buildbotics.upload',
            'buildbotics.file-manager', 'buildbotics.comments'];

    angular
        .module('buildbotics', deps)
        .config(module_config)
        .controller('BodyCtrl', body_controller)
        .controller('ContentCtrl', content_controller)
        .controller('RegisterDialogCtrl', register_dialog_controller)
        .controller('ProfileCtrl', profile_controller)
        .controller('CreateCtrl', create_controller)
        .run(buildbotics_run)

    angular.bootstrap(document.documentElement, ['buildbotics']);
})
