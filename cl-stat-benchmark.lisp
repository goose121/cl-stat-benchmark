;; Copyright 2021 Morgan Hager

;; This file is part of cl-stat-benchmark.

;; cl-stat-benchmark is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; cl-stat-benchmark is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU Affero General Public License for more details.

;; You should have received a copy of the GNU Affero General Public License
;; along with cl-stat-benchmark.  If not, see <https://www.gnu.org/licenses/>.


(in-package #:cl-stat-benchmark)

(export
 '(benchmark-results
   func-name
   runtimes
   results-empty-p
   clear-results
   summarize-results
   benchmark-race-results
   results-1
   results-2
   test-race-results
   matched-benchmark-external-data
   modify-matched-results
   matched-race-results
   clear-results
   matched-benchmark-results
   make-matched-benchmark-results
   benchmark-sample-matched
   benchmark-sample))

(defgeneric results-empty-p (results)
  (:documentation "Tests whether RESULTS contains no data."))

(defgeneric clear-results (results)
  (:documentation "Clears all data from RESULTS."))

(defgeneric summarize-results (results &key stream &allow-other-keys)
  (:documentation "Prints a summary of RESULTS on STREAM (defaults to
  *STANDARD-OUTPUT*). The keyword arguments allow specific result
  types to have their own options for printing."))

(defgeneric test-race-results (results &optional test)
  (:documentation "Performs a statistical test to determine whether
  the first function in RESULTS is slower, as fast as, or faster than
  the second, determined by TEST being the symbol >, =, or <
  respectively."))

(defgeneric make-matched-benchmark-results (class &rest initargs &key &allow-other-keys)
  (:documentation "Creates an instance of CLASS which is also an
  instance of MATCHED-BENCHMARK-RESULTS using INITARGS. The class
  precedence order of the instance will be (MATCHED-BENCHMARK-RESULTS
  CLASS)."))

(defgeneric benchmark-sample-matched (comparative-results func1 func2 sample-num &rest sample-args &key &allow-other-keys)
  (:documentation "Times first FUNC1, then FUNC2, storing the results
  in COMPARATIVE-RESULTS. Each function is called with SAMPLE-NUM as
  its only argument. This function allows for sampling
  MATCHED-BENCHMARK-RESULTS."))

(defgeneric benchmark-sample (results func sample-num &key &allow-other-keys)
  (:documentation "Times running FUNC once with the argument
  SAMPLE-NUM, then add the result to RESULTS."))

(defclass benchmark-results ()
  ((func-name :initform "" :reader func-name)
   (runtimes :initform '() :initarg :runtimes :accessor runtimes))
  (:documentation "Holds the results of benchmarking a function."))

(defmethod results-empty-p ((results benchmark-results))
  (null (runtimes results)))

(defmethod clear-results ((results benchmark-results))
  (setf (runtimes results) '()))

(defmethod initialize-instance :after ((results benchmark-results) &key function default-name &allow-other-keys)
  (setf (slot-value results 'func-name)
        (cond
          ((symbolp function)
           (symbol-name function))
          ((listp function)
           (princ-to-string function))
          ((stringp function)
           function)
          (t default-name))))

(defmethod summarize-results ((results benchmark-results) &key (stream *standard-output*) &allow-other-keys)
  (multiple-value-bind (length min max range median mode mean variance stddev iqr)
      (cl-mathstats:statistical-summary (mapcar (lambda (time) (coerce (/ time internal-time-units-per-second) 'double-float)) (runtimes results)))
    (macrolet
        ((print-vars (&rest vars)
           `(format stream ,(let ((*print-case* :downcase)) (format nil "~{  ~A = ~~A~~%~}" vars))
                    ,@vars)))
      (format stream "~A:~%" (func-name results))
      (print-vars length min max range median mode mean variance stddev iqr))))

(defclass benchmark-race-results ()
  ((results-1 :initarg :results-1 :reader results-1)
   (results-2 :initarg :results-2 :reader results-2))
  (:documentation "Holds the results of two separate functions,
  allowing them to be compared by a T-test."))

(defmethod test-race-results ((results benchmark-race-results) &optional (test '=))
  (cl-mathstats:t-test
   (runtimes (results-1 results))
   (runtimes (results-2 results))
   (ecase test
     (= :both)
     (< :negative)
     (> :positive))))

(define-condition matched-benchmark-external-data (error)
  ((data :initarg :data :reader data)
   (results :initarg :results :reader results))
  (:report (lambda (c stream) (format stream "Inserting external data ~A into matched benchmark results; this may lead to incorrect calculations" (data c)))))

(defmacro modify-matched-results ((results) &body body)
  (alexandria:once-only (results)
    (alexandria:with-gensyms (c)
     `(handler-bind ((matched-benchmark-external-data
                       (lambda (,c)
                         (when (eql (results ,c) ,results)
                           (invoke-restart 'use-data)))))
        ,@body))))

(defclass matched-race-results (benchmark-race-results)
  ()
  (:documentation "Holds the results of two separate functions, as
  subclasses of MATCHED-BENCHMARK-RESULTS, ensuring that the functions
  are only ever run one directly after the other to allow the use of a
  matched T-test."))

(defmethod clear-results ((results benchmark-race-results))
  (modify-matched-results ((results-1 results))
    (clear-results (results-1 results)))
  (modify-matched-results ((results-2 results))
    (clear-results (results-2 results))))

(defclass matched-benchmark-results (benchmark-results)
  ()
  (:documentation "Mixin class for BENCHMARK-RESULTS (see
  MAKE-MATCHED-BENCHMARK-RESULTS to create instances) which signals a
  MATCHED-BENCHMARK-EXTERNAL-DATA error if an attempt is made to
  modify the data other than through the interfaces provided by
  MATCHED-RACE-RESULTS, enforcing that it is only sampled in tandem
  with the other function in the race."))

(defmethod shared-initialize ((results matched-race-results) slot-names &rest initargs &key &allow-other-keys)
  (declare (ignore initargs))
  (call-next-method)
  (dynamic-mixins:ensure-mix (results-1 results) 'matched-benchmark-results)
  (dynamic-mixins:ensure-mix (results-2 results) 'matched-benchmark-results))

(defmethod shared-initialize ((results matched-benchmark-results) slot-names &rest initargs &key &allow-other-keys)
  (when (getf initargs :runtimes)
    (restart-case
        (error 'matched-benchmark-external-data :data (getf initargs :runtimes) :results results)
      (discard-data ()
        :report "Don't use the data."
        ;; Modifying rest-lists is a faux pas
        (setf initargs (copy-list initargs))
        (remf initargs :runtimes))
      (use-data ()
        :report "Continue using the data.")))
  (apply #'call-next-method initargs)
  (dynamic-mixins:ensure-mix (results-1 results) 'matched-benchmark-results)
  (dynamic-mixins:ensure-mix (results-2 results) 'matched-benchmark-results))

(defmethod update-instance-for-different-class :before (previous (current matched-benchmark-results) &rest initargs)
  (declare (ignore initargs))
  (unless (or (typep previous 'matched-benchmark-results) (results-empty-p current))
    (restart-case
        (error 'matched-benchmark-external-data :data (runtimes current) :results current)
      (discard-data ()
        :report "Don't use the data."
        ;; It is very likely that CLEAR-RESULTS will need to modify
        ;; the results in order to do its job, so always invoke
        ;; USE-DATA if it tries to
        (handler-bind ((matched-benchmark-external-data
                         (lambda (c)
                           (declare (ignore c))
                           (invoke-restart 'use-data))))
          (clear-results current)))
      (use-data ()
        :report "Continue using the data."))))

(defmethod (setf runtimes) (new-data (results matched-benchmark-results))
  (restart-case
        (error 'matched-benchmark-external-data :data new-data :results results)
      (discard-data ()
        :report "Don't use the data."
        (runtimes results))
      (use-data ()
        :report "Continue using the data."
        (call-next-method))))

(defmethod make-matched-benchmark-results (class &rest initargs &key &allow-other-keys)
  (apply #'make-instance (dynamic-mixins:mix 'matched-benchmark-results class) initargs))

(defmethod test-race-results ((results matched-race-results) &optional (test '=))
  (cl-mathstats:t-test-matched
   (runtimes (results-1 results))
   (runtimes (results-2 results))
   (ecase test
     (= :both)
     (< :negative)
     (> :positive))))

(defmethod summarize-results ((race-results benchmark-race-results) &key (stream *standard-output*) (test '=) &allow-other-keys)
  (multiple-value-bind
        (t-stat significance stderr dof)
      (test-race-results race-results)
    (summarize-results (results-1 race-results))
    (summarize-results (results-2 race-results))
      (format
       stream
       "P(~A ~A ~A) = ~F (p = ~F, t = ~F, stderr = ~F, dof = ~A)~%"
       (func-name (results-1 race-results))
       (ecase test
         (= "isn't the same speed as")
         (< "isn't faster than")
         (> "isn't slower than"))
       (func-name (results-2 race-results))
       (ecase test
         (= (* 2 (abs (- 0.5 significance))))
         (< significance)
         (> (- 1 significance)))
       significance
       t-stat
       stderr
       dof)))

(defmethod benchmark-sample-matched (comparative-results func1 func2 sample-num &rest sample-args &key &allow-other-keys)
  (let ((func1* (coerce func1 'function))
        (func2* (coerce func2 'function)))
    (modify-matched-results ((results-1 comparative-results))
      (apply #'benchmark-sample (results-1 comparative-results) func1* sample-num sample-args))
    (modify-matched-results ((results-2 comparative-results))
      (apply #'benchmark-sample (results-2 comparative-results) func2* sample-num sample-args))
    comparative-results))

(defmethod benchmark-sample ((results benchmark-results) func sample-num &key &allow-other-keys)
  (push
   (let ((start-time (get-internal-run-time)))
     (funcall func sample-num)
     (- (get-internal-run-time) start-time))
   (runtimes results)))
