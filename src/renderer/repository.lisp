#|
  This file is a part of Clack package.
  URL: http://github.com/fukamachi/clack
  Copyright (c) 2011 Eitarow Fukamachi <e.arrows@gmail.com>

  Clack is freely distributable under the LLGPL License.
|#

(in-package :cl-user)
(defpackage clack.doc.repository
  (:use :cl)
  (:import-from :fad
                :file-exists-p)
  (:import-from :yason
                :parse)
  (:import-from :drakma
                :http-request)
  (:import-from :flexi-streams
                :octets-to-string)
  (:import-from :alexandria
                :when-let)
  (:import-from :org.tfeb.hax.memoize
                :memoize-function)
  (:import-from :clack.doc.util
                :slurp-file))
(in-package :clack.doc.repository)

(cl-annot:enable-annot-syntax)

(defparameter *quicklisp-projects-directory*
              (asdf:system-relative-pathname :clack-doc
               #P"modules/quicklisp-projects/"))

(defun project-source-file (project-name)
  (let ((filepath
         (merge-pathnames (format nil "~A/source.txt" project-name)
                          *quicklisp-projects-directory*)))
    (and (fad:file-exists-p filepath)
         filepath)))

(defun project-repository-url (project-name)
  (when-let (source (project-source-file project-name))
    (let ((data (slurp-file source)))
      (nth-value 0
                 (ppcre:scan-to-strings "(\\S+?://\\S+?)\\s*?$" data)))))

(defun url-domain (url)
  (aref (nth-value 1 (ppcre:scan-to-strings "^[^:]+?://([^/]+)" url))
        0))

@export
(defun project-url (project-name)
  (when-let (repos-url (project-repository-url project-name))
    (let ((domain (url-domain repos-url)))
      (values
       (cond
         ((or (string= domain "github.com")
              (string= domain "gitorious.org"))
          (concatenate 'string
                       "https"
                       (ppcre:scan-to-strings "://.+/[^\.]+" repos-url)))
         ((string= domain "bitbucket.org")
          repos-url))
       domain))))

(defun github-repos-api (project-url)
  (let ((match
            (nth-value 1
                       (ppcre:scan-to-strings "://[^/]+?/([^/]+?)/([^/]+)" project-url))))
    (format nil "https://api.github.com/repos/~A/~A"
            (aref match 0)
            (aref match 1))))

(defun bitbucket-repos-api (project-url)
  (let ((match
            (nth-value 1
                       (ppcre:scan-to-strings "://[^/]+?/([^/]+?)/([^/]+)" project-url))))
    (format nil "https://api.bitbucket.org/1.0/repositories/~A/~A"
            (aref match 0)
            (aref match 1))))

(defun request-homepage-url (api-url key)
  (multiple-value-bind (body status)
      (drakma:http-request api-url)
    (when (= status 200)
      (let ((homepage
             (gethash key
                      (yason:parse
                       (flex:octets-to-string body)))))
        (cond
          ((or (null homepage) (string= homepage "")) nil)
          ((ppcre:scan "^[^:]+://" homepage) homepage)
          (t (concatenate 'string "http://" homepage)))))))
(memoize-function 'request-homepage-url :test 'equal)

@export
(defun repos-homepage (project-name)
  (multiple-value-bind (url domain)
      (project-url project-name)
    (when-let (args (cond
                      ((string= domain "github.com")
                       (list (github-repos-api url) "homepage"))
                      ((string= domain "butbucket.org")
                       (list (bitbucket-repos-api url) "website"))))
      (apply #'request-homepage-url args))))