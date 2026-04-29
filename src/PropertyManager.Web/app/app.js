(function () {
    'use strict';

    angular
        .module('propertyManagerApp', ['ui.router'])
        .config(AppConfig)
        .run(AppRun);

    AppConfig.$inject = ['$stateProvider', '$urlRouterProvider', '$httpProvider'];
    function AppConfig($stateProvider, $urlRouterProvider, $httpProvider) {
        $urlRouterProvider.otherwise('/dashboard');

        $stateProvider
            .state('login', {
                url: '/login',
                templateUrl: 'views/login.html',
                controller: 'LoginController',
                controllerAs: 'vm',
                publicPage: true
            })
            .state('dashboard', {
                url: '/dashboard',
                templateUrl: 'views/dashboard.html',
                controller: 'DashboardController',
                controllerAs: 'vm'
            })
            .state('maintenanceList', {
                url: '/maintenance?status&priority&propertyId&tenantId',
                templateUrl: 'views/maintenance-list.html',
                controller: 'MaintenanceListController',
                controllerAs: 'vm'
            })
            .state('maintenanceNew', {
                url: '/maintenance/new',
                templateUrl: 'views/maintenance-new.html',
                controller: 'MaintenanceNewController',
                controllerAs: 'vm'
            })
            .state('maintenanceDetail', {
                url: '/maintenance/:id',
                templateUrl: 'views/maintenance-detail.html',
                controller: 'MaintenanceDetailController',
                controllerAs: 'vm'
            })
            .state('propertiesList', {
                url: '/properties?search&isActive',
                templateUrl: 'views/properties-list.html',
                controller: 'PropertiesListController',
                controllerAs: 'vm'
            })
            .state('propertyDetail', {
                url: '/properties/:id',
                templateUrl: 'views/property-detail.html',
                controller: 'PropertyDetailController',
                controllerAs: 'vm'
            })
            .state('tenantsList', {
                url: '/tenants?propertyId&search',
                templateUrl: 'views/tenants-list.html',
                controller: 'TenantsListController',
                controllerAs: 'vm'
            });

        $httpProvider.interceptors.push('authInterceptor');
    }

    AppRun.$inject = ['$rootScope', '$state', 'authService'];
    function AppRun($rootScope, $state, authService) {
        $rootScope.currentUser = null;

        authService.getUserInfo().then(function (response) {
            $rootScope.currentUser = response.data;
            authService.markAuthenticated();
        }).catch(function () {
            $rootScope.currentUser = null;
        });

        $rootScope.$on('$stateChangeStart', function (event, toState, toParams) {
            if (toState.publicPage) {
                return;
            }

            if (!authService.isAuthenticated()) {
                event.preventDefault();
                authService.getUserInfo().then(function (response) {
                    $rootScope.currentUser = response.data;
                    authService.markAuthenticated();
                    $state.go(toState.name, toParams);
                }).catch(function () {
                    $state.go('login');
                });
            }
        });
    }
})();
