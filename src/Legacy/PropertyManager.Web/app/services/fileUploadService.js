(function () {
    'use strict';

    angular.module('propertyManagerApp')
        .factory('fileUploadService', fileUploadService);

    fileUploadService.$inject = ['$q', '$http'];

    function fileUploadService($q, $http) {
        var allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'doc', 'docx'];
        var maxBytes = 10 * 1024 * 1024;

        return {
            validate: validate,
            uploadToRequest: uploadToRequest,
            listForRequest: listForRequest,
            getDownloadUrl: getDownloadUrl,
            deleteAttachment: deleteAttachment
        };

        function validate(file) {
            if (!file) {
                return { valid: false, message: 'No file selected.' };
            }

            var extension = file.name.split('.').pop().toLowerCase();
            if (allowedExtensions.indexOf(extension) === -1) {
                return { valid: false, message: 'File type not allowed: ' + extension };
            }

            if (file.size > maxBytes) {
                return { valid: false, message: 'File must be 10MB or less.' };
            }

            return { valid: true };
        }

        function uploadToRequest(requestId, file) {
            var deferred = $q.defer();
            var formData = new FormData();
            formData.append('file', file);

            $.ajax({
                url: '/api/maintenancerequests/' + requestId + '/attachments',
                type: 'POST',
                data: formData,
                processData: false,
                contentType: false,
                xhr: function () {
                    var xhr = $.ajaxSettings.xhr();
                    if (xhr.upload) {
                        xhr.upload.addEventListener('progress', function (evt) {
                            if (evt.lengthComputable) {
                                deferred.notify(Math.round((evt.loaded / evt.total) * 100));
                            }
                        }, false);
                    }
                    return xhr;
                },
                success: function (data) {
                    deferred.resolve(data);
                },
                error: function (xhr) {
                    deferred.reject(xhr.responseJSON || { message: 'Upload failed.' });
                }
            });

            return deferred.promise;
        }

        function listForRequest(requestId) {
            return $http.get('/api/maintenancerequests/' + requestId + '/attachments');
        }

        function getDownloadUrl(attachmentId) {
            return '/api/attachments/' + attachmentId;
        }

        function deleteAttachment(attachmentId) {
            return $http.delete('/api/attachments/' + attachmentId);
        }
    }
})();
