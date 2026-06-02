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
    }

    AppRun.$inject = ['$rootScope', 'authService'];
    function AppRun($rootScope, authService) {
        $rootScope.currentUser = null;

        authService.initialize().then(function (user) {
            $rootScope.currentUser = user;
        }).catch(function () {
            $rootScope.currentUser = null;
        });
    }
})();
