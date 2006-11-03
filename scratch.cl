(in-package :cl-bio)

(defparameter d (make-random-dna-sequence 100))

(residues-string d)

(defparameter df (make-instance 'adjustable-dna-sequence :initial-contents (residues-string (make-random-dna-sequence 1000))))
(defparameter rf (make-instance 'adjustable-rna-sequence :initial-contents (residues-string (make-random-rna-sequence 100))))
(defparameter af (make-instance 'adjustable-aa-sequence :initial-contents (residues-string (make-random-aa-sequence 100))))

(insert-residues df 0 "TTTT")
(insert-residues rf 0 "UUUU")
(insert-residues af 0 "HHHH")

(residues-string df)
(residues-string rf)
(residues-string af)
(seq-length df)

(append-residues df "TTTT")
(append-residues rf "CUCU")
(append-residues af "YYYY")

(insert-residues df 1 "AAAA")
#+nil
(array-element-type (map '(vector (unsigned-byte 2))
                         #'(lambda (x)
                             (char-to-seq-code df x))
                         "TACGT"))

(flexichain:insert-vector*
 (residues df) 0 (map '(vector (unsigned-byte 2))
                      #'(lambda (x)
                          (char-to-seq-code df x))
                      "AAAAA"))


(array-element-type (make-array 5 :initial-contents '(0 0 0 0 0) :element-type '(unsigned-byte 2)))
(slot-value (residues df) 'flexichain::element-type)

(residues-string df)

(let ((r (make-instance 'range :start 10 :end 12)))
  (residues-string-range df r))

