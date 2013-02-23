(in-package :cl-user)
(defpackage quickdocs.readme
  (:use :cl)
  (:import-from :cl-markdown
                :markdown)
  (:import-from :cl-fad
                :list-directory
                :pathname-as-directory)
  (:import-from :trivial-shell
                :get-env-var
                :shell-command)
  (:import-from :alexandria
                :when-let)
  (:import-from :quickdocs.util
                :slurp-file))
(in-package :quickdocs.readme)

(cl-annot:enable-annot-syntax)

(defparameter *pandoc-path*
              (merge-pathnames #P".cabal/bin/pandoc"
                               (fad:pathname-as-directory
                                (trivial-shell:get-env-var "HOME"))))

(defun parse-markdown (file)
  (multiple-value-bind (stdout stderr code)
      (trivial-shell:shell-command
       (format nil "~A ~A" *pandoc-path* file)
       :input "")
    (declare (ignore stderr))
    (if (= 0 code)
        stdout
        ;; fallback to CL-Markdown
        (with-output-to-string (s)
          (cl-markdown:markdown file :stream s)))))

@export
(defmethod find-system-readme ((system asdf:system))
  (remove-if-not
   #'(lambda (path)
       (let ((filename (file-namestring path)))
         (and (>= (length filename) 6)
              (string= "README" (subseq filename 0 6)))))
   (fad:list-directory
    (slot-value system 'asdf::absolute-pathname))))

@export
(defmethod find-system-readme ((system ql-dist:system))
  (when-let (asdf-system
             (ignore-errors
               (asdf:find-system (slot-value system 'ql-dist:name))))
    (find-system-readme asdf-system)))

@export
(defun readme->html (readme-file)
  (let ((ext (pathname-type readme-file)))
    (cond
      ((find ext '("md" "markdown" "mkdn")
             :test #'string-equal)
       (format nil "<div class=\"markdown\">~A</div>"
               (parse-markdown readme-file)))
      (t (format nil "<div class=\"plain-text\">~A</div>"
                 (emb::escape-for-xml (slurp-file readme-file)))))))
