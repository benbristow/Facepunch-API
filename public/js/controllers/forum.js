'use strict';

angular.module('facepunchApp')

.controller('ForumCtrl', ['$scope', 'forum', function($scope, forum) {
  $scope.forum = forum;

  $scope.gotoThread = function(thread) {

  };

}]);
