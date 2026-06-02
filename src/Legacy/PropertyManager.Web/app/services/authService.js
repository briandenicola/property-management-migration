(function () {
    'use strict';

    angular.module('propertyManagerApp')
        .factory('authService', authService);

    authService.$inject = ['$http', '$q'];
    function authService($http, $q) {
        var currentUser = null;
        var loaded = false;

        return {
            initialize: initialize,
            getCurrentUser: getCurrentUser,
            isAuthenticated: isAuthenticated,
            isAdmin: isAdmin,
            logout: logout
        };

        function initialize() {
            return $http.get('/api/account/userinfo').then(function (response) {
                currentUser = response.data;
                loaded = true;
                return currentUser;
            });
        }

        function getCurrentUser() {
            if (loaded) {
                return $q.resolve(currentUser);
            }

            return initialize();
        }

        function isAuthenticated() {
            return currentUser !== null && currentUser.isAuthenticated;
        }

        function isAdmin() {
            return currentUser !== null && currentUser.role === 'Admin';
        }

        function logout() {
            currentUser = null;
            loaded = false;
            return $q.resolve();
        }
    }
})();
