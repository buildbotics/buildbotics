
// Main ************************************************************************
$(function() {
    angular
        .module('markdown-test', ['buildbotics.markdown'])
        .controller('Ctrlr', function ($scope) {
            $scope.content = '#Hello World!';
        });

    angular.bootstrap(document.documentElement, ['markdown-test']);
})
