angular.module('facepunchApp', ['restangular', 'ionic', 'angular-loading-bar'])

.run(function($ionicPlatform) {
  $ionicPlatform.ready(function() {
    // Hide the accessory bar by default (remove this to show the accessory bar above the keyboard
    // for form inputs)
    if (window.cordova && window.cordova.plugins && window.cordova.plugins.Keyboard) {
      cordova.plugins.Keyboard.hideKeyboardAccessoryBar(true);
      cordova.plugins.Keyboard.disableScroll(true);

    }
    if (window.StatusBar) {
      StatusBar.styleLightContent();
    }
  });
})

.config(function($stateProvider, $urlRouterProvider, $ionicConfigProvider, RestangularProvider) {
  //Tabs at bottom for all devices
  $ionicConfigProvider.tabs.position('bottom');

  //RestangularProvider.setBaseUrl('http://localhost:4567/v1');
  RestangularProvider.setBaseUrl('https://fpapi.benbristow.co.uk/v1');

  $stateProvider

  .state('tab', {
    url: '/tab',
    abstract: true,
    templateUrl: 'templates/tabs.html'
  })

  .state('tab.forums', {
    url: '/forums',
    views: {
      'tab-forums': {
        templateUrl: 'templates/tab-forums.html',
        controller: 'ForumsCtrl'
      }
    },
    resolve: {
      forums: function(Forums) {
        return Forums.findAll();
      }
    }
  })

  .state('tab.forum-detail', {
    url: '/forums/:forumId',
    views: {
      'tab-forums': {
        templateUrl: 'templates/forum-detail.html',
        controller: 'ForumCtrl'
      }
    },
    resolve: {
      forum: function(Forums, $stateParams) {
        return Forums.findOne($stateParams.forumId);
      }
    }
  })

  .state('tab.thread-detail', {
    url: '/threads/:threadId?page',
    views: {
      'tab-forums': {
        templateUrl: 'templates/thread-detail.html',
        controller: 'ThreadCtrl'
      }
    },
    resolve: {
      thread: function(Threads, $stateParams) {
        return Threads.findOne($stateParams.threadId, $stateParams.page);
      }
    }
  });


  // if none of the above states are matched, use this as the fallback
  $urlRouterProvider.otherwise('/tab/forums');

});
