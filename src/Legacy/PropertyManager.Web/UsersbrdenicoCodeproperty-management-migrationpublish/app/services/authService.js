(function () {
    'use strict';

    angular.module('propertyManagerApp')
        .factory('authService', authService);
        // authInterceptor disabled — caused circular dep ($http <- authService <- authInterceptor <- $http)
        // .factory('authInterceptor', authInterceptor);

    authService.$inject = ['$http', '$window'];
    function authService($http, $window) {
        var tokenKey = 'propertyManagerToken';
        var authenticated = false;

        return {
            login: login,
            logout: logout,
            getUserInfo: getUserInfo,
            isAuthenticated: isAuthenticated,
            getToken: getToken,
            markAuthenticated: markAuthenticated
        };

        function login(credentials) {
            return $http.post('/api/account/login', credentials).then(function (response) {
                if (response.data && response.data.token) {
                    $window.localStorage.setItem(tokenKey, response.data.token);
                }
                authenticated = true;
                return response;
            });
        }

        function logout() {
            return $http.post('/api/account/logout').finally(function () {
                $window.localStorage.removeItem(tokenKey);
                authenticated = false;
            });
        }

        function getUserInfo() {
            return $http.get('/api/account/userinfo');
        }

        function isAuthenticated() {
            return authenticated || !!getToken();
        }

        function getToken() {
            return $window.localStorage.getItem(tokenKey);
        }

        function markAuthenticated() {
            authenticated = true;
        }
    }

    // authInterceptor disabled — backend auth (OWIN/ASP.NET Identity) has been removed
    // authInterceptor.$inject = ['authService'];
    // function authInterceptor(authService) {
    //     return {
    //         request: function (config) {
    //             var token = authService.getToken();
    //             if (token) {
    //                 config.headers.Authorization = 'Bearer ' + token;
    //             }
    //             return config;
    //         }
    //     };
    // }
})();
