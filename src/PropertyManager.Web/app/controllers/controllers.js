(function () {
    'use strict';

    angular.module('propertyManagerApp')
        .controller('MainController', MainController)
        .controller('DashboardController', DashboardController)
        .controller('MaintenanceListController', MaintenanceListController)
        .controller('MaintenanceDetailController', MaintenanceDetailController)
        .controller('MaintenanceNewController', MaintenanceNewController)
        .controller('PropertiesListController', PropertiesListController)
        .controller('PropertyDetailController', PropertyDetailController)
        .controller('TenantsListController', TenantsListController)
        .controller('LoginController', LoginController);

    MainController.$inject = ['$state', '$rootScope', 'authService'];
    function MainController($state, $rootScope, authService) {
        var vm = this;

        vm.logout = function () {
            authService.logout().finally(function () {
                $rootScope.currentUser = null;
                $state.go('login');
            });
        };

        vm.isLoggedIn = function () {
            return authService.isAuthenticated();
        };
    }

    DashboardController.$inject = ['maintenanceRequestService', 'propertyService', 'tenantService'];
    function DashboardController(maintenanceRequestService, propertyService, tenantService) {
        var vm = this;
        vm.loading = true;
        vm.metrics = {
            totalRequests: 0,
            openRequests: 0,
            inProgressRequests: 0,
            properties: 0,
            tenants: 0
        };

        activate();

        function activate() {
            maintenanceRequestService.getAll({}).then(function (response) {
                var rows = response.data || [];
                vm.metrics.totalRequests = rows.length;
                vm.metrics.openRequests = rows.filter(function (r) { return r.status === 'Open'; }).length;
                vm.metrics.inProgressRequests = rows.filter(function (r) { return r.status === 'InProgress'; }).length;
            });

            propertyService.getAll({ isActive: true }).then(function (response) {
                vm.metrics.properties = (response.data || []).length;
            });

            tenantService.getAll({}).then(function (response) {
                vm.metrics.tenants = (response.data || []).length;
            }).finally(function () {
                vm.loading = false;
            });
        }
    }

    MaintenanceListController.$inject = ['$state', '$stateParams', 'maintenanceRequestService', 'propertyService', 'tenantService'];
    function MaintenanceListController($state, $stateParams, maintenanceRequestService, propertyService, tenantService) {
        var vm = this;
        vm.loading = true;
        vm.requests = [];
        vm.properties = [];
        vm.tenants = [];
        vm.statuses = ['Open', 'InProgress', 'Completed', 'Closed'];
        vm.priorities = ['', 'Low', 'Medium', 'High', 'Emergency'];
        vm.filters = {
            status: $stateParams.status || '',
            priority: $stateParams.priority || '',
            propertyId: $stateParams.propertyId || '',
            tenantId: $stateParams.tenantId || ''
        };

        vm.applyFilters = function () {
            $state.go('maintenanceList', vm.filters, { notify: false });
            loadRequests();
        };

        vm.clearFilters = function () {
            vm.filters = { status: '', priority: '', propertyId: '', tenantId: '' };
            vm.applyFilters();
        };

        loadLookups();
        loadRequests();

        function loadLookups() {
            propertyService.getAll({ isActive: true }).then(function (response) {
                vm.properties = response.data || [];
            });
            tenantService.getAll({}).then(function (response) {
                vm.tenants = response.data || [];
            });
        }

        function loadRequests() {
            vm.loading = true;
            maintenanceRequestService.getAll(vm.filters).then(function (response) {
                vm.requests = response.data || [];
            }).finally(function () {
                vm.loading = false;
            });
        }
    }

    MaintenanceDetailController.$inject = ['$stateParams', 'maintenanceRequestService', 'fileUploadService'];
    function MaintenanceDetailController($stateParams, maintenanceRequestService, fileUploadService) {
        var vm = this;
        vm.loading = true;
        vm.request = null;
        vm.attachments = [];
        vm.uploadMessage = '';
        vm.uploadProgress = 0;
        vm.statuses = [
            { name: 'Open', value: 0 },
            { name: 'InProgress', value: 1 },
            { name: 'Completed', value: 2 },
            { name: 'Closed', value: 3 }
        ];
        vm.statusHistory = [];

        vm.updateStatus = function (statusObj) {
            maintenanceRequestService.updateStatus($stateParams.id, statusObj.value).then(function () {
                vm.request.status = statusObj.value;
                vm.request.statusName = statusObj.name;
                vm.statusHistory.unshift({
                    changedBy: 'Current User',
                    newStatus: statusObj.name,
                    changedOn: new Date()
                });
            });
        };

        vm.onFilesSelected = function (files) {
            if (!files || !files.length) {
                return;
            }

            var file = files[0];
            var validation = fileUploadService.validate(file);
            if (!validation.valid) {
                vm.uploadMessage = validation.message;
                return;
            }

            vm.uploadMessage = '';
            vm.uploadProgress = 0;
            fileUploadService.uploadToRequest($stateParams.id, file).then(function () {
                vm.uploadProgress = 100;
                vm.uploadMessage = 'Upload complete.';
                loadAttachments();
            }, function (err) {
                vm.uploadMessage = (err && err.message) || 'Upload failed.';
            }, function (progress) {
                vm.uploadProgress = progress;
            });
        };

        vm.getDownloadUrl = fileUploadService.getDownloadUrl;

        activate();

        function activate() {
            maintenanceRequestService.getById($stateParams.id).then(function (response) {
                vm.request = response.data;
                vm.statusHistory = vm.request.statusHistory || [];
            }).finally(function () {
                vm.loading = false;
            });

            loadAttachments();
        }

        function loadAttachments() {
            fileUploadService.listForRequest($stateParams.id).then(function (response) {
                vm.attachments = response.data || [];
            });
        }
    }

    MaintenanceNewController.$inject = ['$state', '$q', 'maintenanceRequestService', 'propertyService', 'tenantService', 'fileUploadService'];
    function MaintenanceNewController($state, $q, maintenanceRequestService, propertyService, tenantService, fileUploadService) {
        var vm = this;
        vm.saving = false;
        vm.properties = [];
        vm.tenants = [];
        vm.uploadQueue = [];
        vm.validationMessage = '';

        vm.request = {
            title: '',
            description: '',
            priority: 'Medium',
            status: 'Open',
            propertyId: null,
            tenantId: null
        };

        vm.onFilesSelected = function (files) {
            vm.validationMessage = '';
            angular.forEach(files, function (file) {
                var validation = fileUploadService.validate(file);
                if (!validation.valid) {
                    vm.validationMessage = validation.message;
                    return;
                }

                var item = {
                    file: file,
                    name: file.name,
                    size: file.size,
                    progress: 0,
                    previewUrl: null
                };

                if (/image\//i.test(file.type)) {
                    var reader = new FileReader();
                    reader.onload = function (e) {
                        item.previewUrl = e.target.result;
                    };
                    reader.readAsDataURL(file);
                }

                vm.uploadQueue.push(item);
            });
        };

        vm.removeFile = function (index) {
            vm.uploadQueue.splice(index, 1);
        };

        vm.submit = function () {
            vm.saving = true;
            maintenanceRequestService.create(vm.request).then(function (response) {
                var created = response.data;
                return uploadQueue(created.id).then(function () {
                    $state.go('maintenanceDetail', { id: created.id });
                });
            }).finally(function () {
                vm.saving = false;
            });
        };

        loadLookups();

        function loadLookups() {
            propertyService.getAll({ isActive: true }).then(function (response) {
                vm.properties = response.data || [];
            });
            tenantService.getAll({}).then(function (response) {
                vm.tenants = response.data || [];
            });
        }

        function uploadQueue(requestId) {
            var chain = $q.when();
            angular.forEach(vm.uploadQueue, function (item) {
                chain = chain.then(function () {
                    return fileUploadService.uploadToRequest(requestId, item.file).then(null, null, function (progress) {
                        item.progress = progress;
                    });
                });
            });
            return chain;
        }
    }

    PropertiesListController.$inject = ['$state', '$stateParams', 'propertyService'];
    function PropertiesListController($state, $stateParams, propertyService) {
        var vm = this;
        vm.loading = true;
        vm.properties = [];
        vm.filters = {
            search: $stateParams.search || '',
            isActive: $stateParams.isActive || ''
        };

        vm.search = function () {
            $state.go('propertiesList', vm.filters, { notify: false });
            load();
        };

        vm.clear = function () {
            vm.filters = { search: '', isActive: '' };
            vm.search();
        };

        load();

        function load() {
            vm.loading = true;
            propertyService.getAll(vm.filters).then(function (response) {
                vm.properties = response.data || [];
            }).finally(function () {
                vm.loading = false;
            });
        }
    }

    PropertyDetailController.$inject = ['$stateParams', 'propertyService'];
    function PropertyDetailController($stateParams, propertyService) {
        var vm = this;
        vm.loading = true;
        vm.property = null;
        vm.tenants = [];

        propertyService.getById($stateParams.id).then(function (response) {
            vm.property = response.data;
        });

        propertyService.getTenants($stateParams.id).then(function (response) {
            vm.tenants = response.data || [];
        }).finally(function () {
            vm.loading = false;
        });
    }

    TenantsListController.$inject = ['$state', '$stateParams', 'tenantService', 'propertyService'];
    function TenantsListController($state, $stateParams, tenantService, propertyService) {
        var vm = this;
        vm.loading = true;
        vm.tenants = [];
        vm.properties = [];
        vm.filters = {
            propertyId: $stateParams.propertyId || '',
            search: $stateParams.search || ''
        };

        vm.search = function () {
            $state.go('tenantsList', vm.filters, { notify: false });
            loadTenants();
        };

        tenantService.getAll({}).then(function (response) {
            vm.tenants = response.data || [];
        });

        propertyService.getAll({ isActive: true }).then(function (response) {
            vm.properties = response.data || [];
        });

        loadTenants();

        function loadTenants() {
            vm.loading = true;
            tenantService.getAll(vm.filters).then(function (response) {
                vm.tenants = response.data || [];
            }).finally(function () {
                vm.loading = false;
            });
        }
    }

    LoginController.$inject = ['$state', '$rootScope', 'authService'];
    function LoginController($state, $rootScope, authService) {
        var vm = this;
        vm.credentials = { username: '', password: '', rememberMe: true };
        vm.errorMessage = '';
        vm.working = false;

        vm.login = function () {
            vm.working = true;
            vm.errorMessage = '';
            authService.login(vm.credentials).then(function () {
                return authService.getUserInfo();
            }).then(function (response) {
                $rootScope.currentUser = response.data;
                $state.go('dashboard');
            }).catch(function () {
                vm.errorMessage = 'Login failed. Please check your credentials.';
            }).finally(function () {
                vm.working = false;
            });
        };
    }
})();
