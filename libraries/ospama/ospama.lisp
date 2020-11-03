;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

(in-package :ospama)

;; TODO: Add more typing.

(define-class manager ()
  ((path ""
         :type (or string pathname)))
  (:export-class-name-p t)
  (:export-accessor-names-p t)
  (:accessor-name-transformer #'class*:name-identity))

(define-class os-package ()
  ((name "")
   (version "")
   (dependencies '())
   (synopsis "")
   (home-page "")
   (licenses '()))
  (:export-class-name-p t)
  (:export-accessor-names-p t)
  (:accessor-name-transformer #'class*:name-identity))

(define-class os-package-output ()
  ((name "")
   (parent-package nil
                   :type (or null os-package))
   (path ""
         :type (or string pathname))
   (size 0))
  (:export-class-name-p t)
  (:export-accessor-names-p t)
  (:accessor-name-transformer #'class*:name-identity)
  (:documentation "OS package outputs are meaningful mostly for functional
package managers like Nix or Guix."))

(define-class os-generation ()
  ((id 0)
   (current? nil)
   (package-count 0)
   (date (local-time:now))
   (path ""
         :type (or string pathname)))
  (:export-class-name-p t)
  (:export-accessor-names-p t)
  (:accessor-name-transformer #'class*:name-identity)
  (:documentation "OS generation"))

(export-always '*manager*)
(defvar *manager* nil
  "The currently selected package manager.
If unset, it will default to the first `*detected-managers*'.")

(export-always '*detected-managers*)
(defvar *detected-managers* '()
  "The list of keywords corresponding to the detected managers.")

;; TODO: What would be an ideal default location?
(defvar profile-directory (uiop:xdg-data-home "profiles"))
(defvar manifest-directory (uiop:xdg-data-home "manifests"))

(defun detect-manager (name class-sym)
  "Prepend the CLASS-SYM instance to `*detected-managers*' if NAME is an
executable that can be found.
NAME can be also be a path."
  (serapeum:and-let* ((path (serapeum:resolve-executable name)))
    (push (make-instance class-sym :path path)
          *detected-managers*)))

(defun manager ()
  (unless *manager*
    (setf *manager* (first *detected-managers*)))
  *manager*)

(declaim (ftype (function (list) uiop/launch-program::process-info) run))
(defun run (command)
  "Run COMMAND over ARGS in the background.
Use the returned `process-info' to check the output and the process termination."
  (the (values uiop/launch-program::process-info &optional)
       (uiop:launch-program command
                            :output :stream
                            :error-output :output)))
(export-always 'list-packages)
(defun list-packages (&optional profile)
  (manager-list-packages (manager) profile))

(defgeneric manager-list-packages (manager &optional profile)
  (:method ((manager manager) &optional profile)
    (declare (ignorable profile))
    (error "Unspecified manager method"))
  (:documentation "Return the list of packages in PROFILE.  If PROFILE is nil,
return all packages.  For functional package manager, return the list of outputs
when PROFILE is specified."))

(export-always 'list-package-outputs)
(defun list-package-outputs ()
  (manager-list-package-outputs (manager)))

(defgeneric manager-list-package-outputs (manager)
  (:method ((manager manager))
    (error "Unspecified manager method"))
  (:documentation "Return the list of all package outputs.
This only needs to be implemented for package managers that support outputs."))

(export-always 'find-os-package)
(defun find-os-package (name)
  (manager-find-os-package (manager) name))

(defgeneric manager-find-os-package (manager name)
  (:method ((manager manager) name)
    (declare (ignorable name))
    (error "Unspecified manager method"))
  (:documentation "Return the package matching NAME."))

(export-always 'list-profiles)
(defun list-profiles (&key include-manager-p)
  (manager-list-profiles (manager) :include-manager-p include-manager-p))

(defgeneric manager-list-profiles (manager &key include-manager-p)
  (:method ((manager manager) &key include-manager-p)
    (declare (ignorable include-manager-p))
    (error "Unspecified manager method"))
  (:documentation "Return all profiles as a list of strings.
With INCLUDE-MANAGER-P, also return the package manager own profile."))

(export-always 'list-manifests)
(defun list-manifests ()
  (manager-list-manifests (manager)))

(defmethod manager-list-manifests ((manager manager))
  (uiop:directory-files (uiop:ensure-directory-pathname manifest-directory)))

(export-always 'list-generations)
(defun list-generations (&optional profile)
  (manager-list-generations (manager) profile))

(defgeneric manager-list-generations (manager &optional profile)
  (:method ((manager manager) &optional profile)
    (declare (ignorable profile))
    (error "Unspecified manager method"))
  (:documentation "Return the generations, optionally for PROFILE."))

(export-always 'switch-generation)
(defun switch-generation (generation &optional profile)
  (manager-switch-generation (manager) generation profile))

(defgeneric manager-switch-generation (manager generation &optional profile)
  (:method ((manager manager) (generation os-generation) &optional profile)
    (declare (ignorable profile))
    (error "Unspecified manager method"))
  (:documentation "Switch PROFILE to generation ID."))

(export-always 'delete-generations)
(defun delete-generations (generations &optional profile)
  (manager-delete-generations (manager) generations profile))

(defgeneric manager-delete-generations (manager generations &optional profile)
  (:method ((manager manager) generations &optional profile)
    (declare (ignorable generations profile))
    (error "Unspecified manager method"))
  (:documentation "Delete GENERATIONS from PROFILE."))

(export-always 'install)
(defun install (package-list &optional profile)
  (manager-install (manager) package-list profile))

(defmethod manager-install ((manager manager) package-list &optional profile)
  (run (append (install-command manager profile) (mapcar #'name package-list))))

(export-always 'install-command)
(defgeneric install-command (manager profile)
  (:method ((manager manager) profile)
    (declare (ignorable profile))
    (error "Unspecified manager method"))
  (:documentation "Return the package manager command (as a list of string)
to install a manifest."))

(export-always 'install-manifest)
(defun install-manifest (manifest &optional profile)
  (manager-install-manifest (manager) manifest profile))

(defmethod manager-install-manifest ((manager manager) manifest &optional profile)
  (run (append (install-manifest-command manager profile)
               (list manifest))))

(export-always 'install-manifest-command)
(defgeneric install-manifest-command (manager profile)
  (:method ((manager manager) profile)
    (declare (ignorable profile))
    (error "Unspecified manager method"))
  (:documentation "Return the package manager command (as a list of string)
to install a manifest."))

(export-always 'uninstall)
(defun uninstall (package-list &optional profile)
  (manager-uninstall (manager) package-list profile))

(defmethod manager-uninstall ((manager manager) package-list &optional profile)
  (run (append (uninstall-command manager profile)
               (mapcar #'name package-list))))

(export-always 'uninstall-command)
(defgeneric uninstall-command (manager profile)
  (:method ((manager manager) profile)
    (declare (ignorable profile))
    (error "Unspecified manager method"))
  (:documentation "Return the package manager command (as a list of string)
to uninstall packages"))

(defun list-files-recursively (directory)
  (let ((result '()))
    (uiop:collect-sub*directories
     (uiop:ensure-directory-pathname directory)
     (constantly t) (constantly t)
     (lambda (subdirectory)
       (setf result (nconc result
                           (uiop:directory-files subdirectory)))))
    result))

(export-always 'list-files)
(defun list-files (package-or-output-list)
  (manager-list-files (manager) package-or-output-list))
