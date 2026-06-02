(function () {
    'use strict';

    angular.module('propertyManagerApp')
        .factory('propertyService', propertyService);

    propertyService.$inject = ['$http'];

    function propertyService($http) {
        var baseUrl = '/api/properties';

        return {
            getAll: function (params) {
                return $http.get(baseUrl, { params: params });
            },
            getById: function (id) {
                return $http.get(baseUrl + '/' + id);
            },
            getTenants: function (id) {
                return $http.get(baseUrl + '/' + id + '/tenants');
            },
            create: function (property) {
                return $http.post(baseUrl, property);
            },
            update: function (id, property) {
                return $http.put(baseUrl + '/' + id, property);
            }
        };
    }
})();
