'use strict';

angular.module('facepunchApp')

.controller('ThreadCtrl', ['$scope', 'thread', 'Threads', '$ionicScrollDelegate', function($scope, thread, Threads, $ionicScrollDelegate) {
  $scope.thread = thread;

  $scope.nextPage = function() {
    Threads.findOne($scope.thread.id, $scope.thread.page + 1).then(function(thread) {
      $scope.thread = thread;
      $ionicScrollDelegate.scrollTop();
    });
  }

  $scope.prevPage = function() {
    if($scope.thread.page > 1) {
      Threads.findOne($scope.thread.id, $scope.thread.page - 1).then(function(thread) {
        $scope.thread = thread;
        $ionicScrollDelegate.scrollTop();
      });
    }
  }

}]);
