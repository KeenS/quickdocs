#|
  This file is a part of Clack package.
  URL: http://github.com/fukamachi/clack
  Copyright (c) 2011 Eitarow Fukamachi <e.arrows@gmail.com>

  Clack is freely distributable under the LLGPL License.
|#

(in-package :cl-user)
(defpackage clack.doc.readme
  (:use :cl)
  (:import-from :cl-markdown
                :markdown)
  (:import-from :cl-fad
                :list-directory)
  (:import-from :alexandria
                :copy-stream)
  (:import-from :flexi-streams
                :octets-to-string
                :with-output-to-sequence))
(in-package :clack.doc.readme)

(cl-annot:enable-annot-syntax)

@export
(defun find-system-readme (system)
  (remove-if-not
   #'(lambda (path)
       (let ((filename (file-namestring path)))
         (and (>= (length filename) 6)
              (string= "README" (subseq filename 0 6)))))
   (fad:list-directory
    (slot-value system 'asdf::absolute-pathname))))

@export
(defun readme->html (readme-file)
  (let ((ext (pathname-type readme-file)))
    (cond
      ((find ext '("md" "markdown" "mkdn")
             :test #'string-equal)
       (with-output-to-string (s)
         (cl-markdown:markdown readme-file :stream s)))
      (t (slurp-file readme-file)))))

(defun slurp-file (file)
  (with-open-file (in file :element-type '(unsigned-byte 8))
    (flex:octets-to-string
     (flex:with-output-to-sequence (out)
      (alexandria:copy-stream in out :finish-output t))
     :external-format :utf-8)))