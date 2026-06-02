(function () {
    'use strict';

    angular.module('propertyManagerApp')
        .factory('tenantService', tenantService);

    tenantService.$inject = ['$http'];

    function tenantService($http) {
        var baseUrl = '/api/tenants';

        return {
            getAll: function (params) {
                return $http.get(baseUrl, { params: params });
            },
            getById: function (id) {
                return $http.get(baseUrl + '/' + id);
            },
            create: function (tenant) {
                return $http.post(baseUrl, tenant);
            },
            update: function (id, tenant) {
                return $http.put(baseUrl + '/' + id, tenant);
            }
        };
    }
})();
