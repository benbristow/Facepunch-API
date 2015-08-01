'use strict';

angular.module('facepunchApp')

.factory('Threads', ['Restangular', function (Restangular) {
    var _rest = Restangular.all('threads');
    return {
      findOne: function(id, page){
        if(typeof page === "undefined") {
          page = 1;
        }

        return _rest.get(id + "?page=" + page).then(function(res){ return res.data });
      }
    };
  }
]);
