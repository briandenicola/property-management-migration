(function () {
    'use strict';

    angular.module('propertyManagerApp')
        .directive('fileChange', fileChange)
        .directive('fileDropzone', fileDropzone);

    function fileChange() {
        return {
            restrict: 'A',
            scope: {
                fileChange: '&'
            },
            link: function (scope, element) {
                element.on('change', function (event) {
                    var files = event.target.files;
                    scope.$apply(function () {
                        scope.fileChange({ files: files });
                    });
                });
            }
        };
    }

    function fileDropzone() {
        return {
            restrict: 'A',
            scope: {
                fileDropzone: '&'
            },
            link: function (scope, element) {
                element.on('dragover', function (event) {
                    event.preventDefault();
                    event.stopPropagation();
                    element.addClass('drag-over');
                });

                element.on('dragleave', function (event) {
                    event.preventDefault();
                    event.stopPropagation();
                    element.removeClass('drag-over');
                });

                element.on('drop', function (event) {
                    event.preventDefault();
                    event.stopPropagation();
                    element.removeClass('drag-over');

                    var files = event.originalEvent && event.originalEvent.dataTransfer
                        ? event.originalEvent.dataTransfer.files
                        : [];

                    scope.$apply(function () {
                        scope.fileDropzone({ files: files });
                    });
                });
            }
        };
    }
})();
