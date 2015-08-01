'use strict';

angular.module('facepunchApp')

.controller('ForumsCtrl', ['$scope', 'forums', '$state', function($scope, forums, $state) {
  $scope.forums = forums;
}]);
