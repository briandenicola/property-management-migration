(function () {
    'use strict';

    angular.module('propertyManagerApp')
        .factory('maintenanceRequestService', maintenanceRequestService);

    maintenanceRequestService.$inject = ['$http'];

    function maintenanceRequestService($http) {
        var baseUrl = '/api/maintenancerequests';

        return {
            getAll: function (params) {
                return $http.get(baseUrl, { params: params });
            },
            getById: function (id) {
                return $http.get(baseUrl + '/' + id);
            },
            create: function (request) {
                return $http.post(baseUrl, request);
            },
            update: function (id, request) {
                return $http.put(baseUrl + '/' + id, request);
            },
            updateStatus: function (id, status) {
                return $http.put(baseUrl + '/' + id + '/status', { status: status });
            },
            assign: function (id, userId) {
                return $http.put(baseUrl + '/' + id + '/assign', { userId: userId });
            }
        };
    }
})();
