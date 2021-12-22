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

(asdf:defsystem #:cl-stat-benchmark
  :description "Benchmark functions and compare the results using statistical tests"
  :author "Morgan Hager <goose121@users.noreply.github.com>"
  :license  "GNU Affero General Public License, version 3 or later"
  :version "0.0.1"
  :depends-on (#:dynamic-mixins
               #:cl-mathstats
               #:alexandria)
  :serial t
  :components ((:file "package")
               (:file "cl-stat-benchmark")))
