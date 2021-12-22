# cl-stat-benchmark

This is a library for benchmarking functions and using statistical
tests to analyze the results.

## Examples

To benchmark the function `foo`, sampling it 1000 times, and print out
a statistical summary of the results:

    (loop :with results := (make-instance 'benchmark-results :function 'foo)
          :for sample-num :from 0 :below 1000
          :do (benchmark-sample results #'foo sample-num)
          :finally (summarize-results results))

To benchmark the function `foo` against the function `bar`, testing
the probability that `foo` is faster than `bar` with a one-tailed
matched T test and again sampling 1000 times, then print out a
summary:

    (loop :with results := (make-instance
                            'matched-race-results
                            ;; Note: MAKE-INSTANCE could also be used
                            ;; here, as the INITIALIZE-INSTANCE method for
                            ;; MATCHED-RACE-RESULTS automatically adds the
                            ;; MATCHED-BENCHMARK-RESULTS mixin
                            :results-1 (make-matched-benchmark-results 'benchmark-results :function 'foo)
                            :results-2 (make-matched-benchmark-results 'benchmark-results :function 'bar))
          :for sample-num :from 0 :below 1000
          :do (benchmark-sample-matched results #'foo #'bar sample-num)
          :finally (summarize-results results))

## License

    This program is free software: you can redistribute it and/or
    modify it under the terms of the GNU Affero General Public License
    as published by the Free Software Foundation, either version 3 of
    the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public
    License along with this program.  If not, see
    <https://www.gnu.org/licenses/>.

_Copyright Morgan Hager 2021 <https://github.com/goose121>_