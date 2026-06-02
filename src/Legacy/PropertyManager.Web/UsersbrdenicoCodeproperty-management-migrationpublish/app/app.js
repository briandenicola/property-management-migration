(function () {
    'use strict';

    angular
        .module('propertyManagerApp', ['ui.router'])
        .config(AppConfig)
        .run(AppRun);

    AppConfig.$inject = ['$stateProvider', '$urlRouterProvider'];
    function AppConfig($stateProvider, $urlRouterProvider) {
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

        // authInterceptor disabled — backend auth (OWIN/ASP.NET Identity) has been removed
        // $httpProvider.interceptors.push('authInterceptor');
    }

    AppRun.$inject = ['$rootScope'];
    function AppRun($rootScope) {
        $rootScope.currentUser = null;
        // Auth guard disabled — backend auth (OWIN/ASP.NET Identity) has been removed
    }
})();
