'use strict';

angular.module('facepunchApp')

.factory('Forums', ['Restangular', function (Restangular) {
    var _rest = Restangular.all('forums');
    return {
      findAll: function(query){
        return _rest.customGET('', query).then(function(res){
          return res.data;
        });
      },
      findOne: function(id){
        return _rest.get(id).then(function(res){ return res.data });
      }
    };
  }
]);
