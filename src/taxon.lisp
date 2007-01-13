;;; Taxon
;;; Classes, generic functions, methods and functions for working
;;; with taxonomy data
;;;
;;; Copyright (c) 2006 Cyrus Harmon (ch-lisp@bobobeach.com)
;;; All rights reserved.
;;;
;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions
;;; are met:
;;;
;;;   * Redistributions of source code must retain the above copyright
;;;     notice, this list of conditions and the following disclaimer.
;;;
;;;   * Redistributions in binary form must reproduce the above
;;;     copyright notice, this list of conditions and the following
;;;     disclaimer in the documentation and/or other materials
;;;     provided with the distribution.
;;;
;;; THIS SOFTWARE IS PROVIDED BY THE AUTHOR 'AS IS' AND ANY EXPRESSED
;;; OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;;; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;; ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
;;; DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
;;; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
;;; GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
;;; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
;;; WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;;; NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;;; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;;;

(in-package :cl-bio)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Taxon

;;; taxon protocol class

(defclass taxon (bio-object)
  ((tax-id :accessor tax-id :initarg :tax-id)
   (parent-id :accessor parent-id :initarg :parent-id)
   (rank :accessor rank :initarg :rank)
   (embl-code :accessor embl-code :initarg :embl-code)
   (division-id :accessor division-id :initarg :division-id)
   (division-inherited :accessor division-inherited :initarg :division-inherited)
   (genetic-code-id :accessor genetic-code-id :initarg :genetic-code-id)
   (genetic-code-inherited :accessor genetic-code-inherited :initarg :genetic-code-inherited)
   (mitochondrial-genetic-code-id
    :accessor mitochondrial-genetic-code-id
    :initarg :mitochondrial-genetic-code-id)
   (mitochondrial-genetic-code-inherited
    :accessor mitochondrial-genetic-code-inherited
    :initarg :mitochondrial-genetic-code-inherited)
   (genbank-hidden :accessor genbank-hidden :initarg :genbank-hidden)
   (hidden-subtree :accessor hidden-subtree :initarg :hidden-subtree)
   (comments :accessor comments :initarg :comments)))

;;; tax-name protocol class

(defclass tax-name ()
  ((tax-id :accessor tax-id :initarg :tax-id)
   (name :accessor name :initarg :name)
   (unique-name :accessor unique-name :initarg :unique-name)
   (name-class :accessor name-class :initarg :name-class)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; rucksack persistent classes

(eval-when (:compile-toplevel :load-toplevel :execute)
  (rucksack:with-rucksack (rucksack *bio-rucksack*)
    (rucksack:with-transaction ()
      (defclass p-taxon (taxon)
        ((tax-id :accessor tax-id :initarg :tax-id :unique t :index :number-index)
         (parent-id :accessor parent-id :initarg :parent-id :index :number-index)
         (rank :accessor rank :initarg :rank)
         embl-code
         division-id
         division-inherited
         genetic-code-id
         genetic-code-inherited
         mitochondrial-genetic-code-id
         mitochondrial-genetic-code-inherited
         genbank-hidden
         hidden-subtree
         comments)
        (:index t)
        (:metaclass rucksack:persistent-class))
      (defclass p-tax-name (tax-name)
        ((tax-id :accessor tax-id :initarg :tax-id :index :number-index)
         (name :accessor name :initarg :name :index :string-index)
         unique-name
         name-class)
        (:index t)
        (:metaclass rucksack:persistent-class)))))

(defparameter *taxonomy-data-directory*
  (merge-pathnames #p"data/taxonomy/"
                   (user-homedir-pathname)))

(defparameter *tax-nodes-file*
  (merge-pathnames #p"taxdump/nodes.dmp"
                   *taxonomy-data-directory*))

(defparameter *tax-names-file*
  (merge-pathnames #p"taxdump/names.dmp"
                   *taxonomy-data-directory*))

(defmacro string-int-boolean (arg)
  `(not (zerop (parse-integer ,arg))))

(defun parse-tax-nodes (&key (file *tax-nodes-file*))
  (let ((batch-size 500))
    (flet ((parse-batch (stream)
             (rucksack:with-rucksack (rucksack *bio-rucksack*)
               (rucksack::without-rucksack-gcing
                 (rucksack:with-transaction ()
                   (loop for i below batch-size
                      for line = (read-line stream nil nil)
                      while line
                      do
                      (let ((strings (cl-ppcre:split "\\t\\|\\t" line)))
                        (print strings)
                        (destructuring-bind
                              (tax-id
                               parent-id
                               rank
                               embl-code
                               division-id
                               division-inherited
                               genetic-code-id
                               genetic-code-inherited
                               mitochondrial-genetic-code-id
                               mitochondrial-genetic-code-inherited
                               genbank-hidden
                               hidden-subtree
                               comments)
                            strings
                          (let ((tax-id (parse-integer tax-id))
                                (parent-id (parse-integer parent-id)))
                            (make-instance 'p-taxon
                                           :tax-id tax-id
                                           :parent-id parent-id
                                           :rank rank
                                           :embl-code embl-code
                                           :division-id (parse-integer division-id)
                                           :division-inherited (string-int-boolean
                                                                division-inherited)
                                           :genetic-code-id (parse-integer genetic-code-id)
                                           :genetic-code-inherited (string-int-boolean
                                                                    genetic-code-inherited)
                                           :mitochondrial-genetic-code-id (parse-integer
                                                                           mitochondrial-genetic-code-id)
                                           :mitochondrial-genetic-code-inherited
                                           (string-int-boolean mitochondrial-genetic-code-inherited)
                                           :genbank-hidden (string-int-boolean genbank-hidden)
                                           :hidden-subtree (string-int-boolean hidden-subtree)
                                           :comments (subseq comments 0 (- (length comments) 2))))))
                      finally (return line)))))))
      (with-open-file (stream file)
        (loop with eof = nil
           while (not eof)
           do (setf eof (not (parse-batch stream))))))))

(defun get-tax-node (id)
  (rucksack:with-rucksack (rucksack *bio-rucksack*)
    (rucksack:with-transaction ()
      (let ((objects))
        (rucksack:rucksack-map-slot
         rucksack 'p-taxon 'tax-id
         (lambda (x)
           (push x objects))
         :equal id)
        (nreverse objects)))))

(defun get-tax-node-children (id)
  (rucksack:with-rucksack (rucksack *bio-rucksack*)
    (rucksack:with-transaction ()
      (let ((objects))
        (rucksack:rucksack-map-slot
         rucksack 'p-taxon 'parent-id
         (lambda (x)
           (unless (= id (tax-id x))
             (push x objects)))
         :equal id)
        (nreverse objects)))))

(defun get-tax-node-ancestors  (id)
  (labels ((%get-tax-node-ancestors (id)
             (let ((node (car (get-tax-node id))))
               (when node (if (= (parent-id node) id)
                              (list id)
                              (cons id (%get-tax-node-ancestors (parent-id node))))))))
    (%get-tax-node-ancestors id)))

(defun parse-tax-names (&key (file *tax-names-file*))
  (let ((batch-size 500))
    (flet ((parse-batch (stream)
             (rucksack:with-rucksack (rucksack *bio-rucksack*)
               (rucksack::without-rucksack-gcing
                 (rucksack:with-transaction ()
                   (print 'new-transaction)
                   (loop for line = (read-line stream nil nil)
                      for i below batch-size
                      while line
                      do
                        (let ((strings (cl-ppcre:split "\\t\\|\\t" line)))
                          (print strings)
                          (destructuring-bind
                                (tax-id
                                 name
                                 unique-name
                                 name-class)
                              strings
                            (let ((tax-id (parse-integer tax-id))
                                  (unique-name (if (plusp (length unique-name))
                                                   unique-name
                                                   name)))
                              (make-instance 'p-tax-name
                                             :tax-id tax-id
                                             :name name
                                             :unique-name unique-name
                                             :name-class (subseq name-class 0 (- (length name-class) 2))))))
                        
                      finally (return line)))))))
      (with-open-file (stream file)
        (loop with eof = nil
           while (not eof)
           do (setf eof (not (parse-batch stream))))))))

(defun get-tax-names (id)
  (rucksack:with-rucksack (rucksack *bio-rucksack*)
    (rucksack:with-transaction ()
      (let ((objects))
        (rucksack:rucksack-map-slot
         rucksack 'p-tax-name 'tax-id
         (lambda (x)
           (push x objects))
         :equal id)
        (nreverse objects)))))

(defun get-preferred-tax-name (id)
  (let ((names (get-tax-names id)))
    (when names
      (name (or (find "scientific name" names :test 'equal :key #'name-class)
                (car names))))))

(defun lookup-tax-name (name)
  (rucksack:with-rucksack (rucksack *bio-rucksack*)
    (rucksack:with-transaction ()
      (let ((objects))
        (rucksack:rucksack-map-slot
         rucksack 'p-tax-name 'name
         (lambda (x)
           (push x objects))
         :min name :include-min t
         :max (let ((max-name (copy-seq name))
                    (len (length name)))
                (setf (elt max-name (1- len))
                      (code-char (1+ (char-code (elt max-name (1- len))))))
                max-name))
        (nreverse objects)))))

(defun get-tax-node-ancestor-names (id)
  (mapcar #'(lambda (x)
              (let ((name
                     (let ((names (get-tax-names
                                   (tax-id
                                    (car (get-tax-node x))))))
                       (find "scientific name" names :test 'equal :key #'name-class))))
                (when name (name name))))
          (get-tax-node-ancestors id)))

;;;; loading

(defun load-taxon-data ()
  (parse-tax-nodes)
  (parse-tax-names))

;;;; misc junk

#+nil
(defun set-tax-node-rank (id rank)
  (rucksack:with-rucksack (rucksack *bio-rucksack*)
    (rucksack:with-transaction ()
      (let ((objects))
        (rucksack:rucksack-map-slot
         rucksack 'p-taxon 'tax-id
         (lambda (x)
           (push x objects))
         :equal id)
        (setf objects (nreverse objects))
        (setf (rank (car objects))
              rank)
        objects))))

