
(asdf:load-system :cl-bio-entrez)

(in-package :entrez-user)

;; (entrez::http-get-entrez-dtds)

;;; xpath stuff

(defun join-xpath-result (result)
  (if (xpath:node-set-p result)
      (format nil "~{~a~^~&~}"
              (xpath:map-node-set->list #'xpath:string-value result))
      (xpath:string-value result)))


;;; ESR1

;;; search entrez the entrez "gene" database for the terms "ESR1" and
;;; "estrogen"
(defparameter *esr1-gene-search*
  (bio:lookup "ESR1[sym] human[ORGN]" *entrez-dictionary* :database "gene"))

;;; get the id first hit from the search set returned above, and load
;;; the corresponding gene from the entrez "gene" database.
(defparameter *esr1-gene*
  (car (bio:members
        (bio:fetch (bio:id (car (bio:members *esr1-gene-search*)))
                   *entrez-dictionary*
                   :database "gene"))))

(defparameter *esr1-nucleotide-search*
  (bio:lookup "ESR1[sym] human[ORGN]"
              *entrez-dictionary*
              :database "nucleotide"))

;;
;; the problem with this is that there are a ton of products in the
;; gene report. how do we know which one we want to use?
(defparameter *esr1-nucleotide-from-gene*
  (car (bio:members
        (bio:fetch
         (bio:id
          (car (bio:get-genbank-accessions
                (car (bio:gene-products *esr1-gene*)))))
         *entrez-dictionary*))))

(defparameter *esr1-nucleotide-search*
  (bio:lookup "ESR1 AND human[ORGN]"
              *entrez-dictionary*
              :database "nucleotide"))

(defparameter *esr1-nucleotide-results*
  (bio:fetch (bio:id (car (bio:members *esr1-nucleotide-search*)))
             *entrez-dictionary*
             :database "nucleotide"))

(defparameter *esr1-nucleotide*
  (car (bio:members
        (bio:fetch (bio:id (car (bio:members *esr1-nucleotide-search*)))
                   *entrez-dictionary*
                   :database "nucleotide"))))

(defparameter *esr1-protein-search*
  (bio:lookup "estrogen receptor alpha isoform 1"
              *entrez-dictionary*
              :database "protein"))

(defparameter *esr1-protein*
  (car (bio:members
        (bio:fetch (bio:id (car (bio:members *esr1-protein-search*)))
                   *entrez-dictionary*
                   :database "protein"))))

(mapcar #'generif-text
        (bio:get-descriptors *esr1-gene* :type 'generif))

(let ((range
       (bio:alpha-range
        (car 
         (bio:filter-alignments
          (bio:get-annotations *esr1-nucleotide* :type 'bio:simple-pairwise-alignment)
          'bio:cds)))))
  (with-accessors ((start bio:range-start)
                 (end bio:range-end))
      range
    (bio:residues-string (bio:translate *esr1-nucleotide* :range range))))

(bio::find-matches "AUA" (bio:residues-string *esr1-nucleotide*))

;;; ESR2
(defparameter *esr2-gene-search*
  (bio:lookup "ESR2 estrogen" *entrez-dictionary* :database "gene"))

(defparameter *esr2-gene*
  (car (bio:members
        (bio:fetch (bio:id (car (bio:members *esr2-gene-search*)))
                   *entrez-dictionary*
                   :database "gene"))))

(defparameter *esr2-nucleotide*
  (car (bio:members (bio:fetch
                     (bio:id
                      (car (bio:get-genbank-accessions
                            (car (bio:gene-products *esr2-gene*)))))
                     *entrez-dictionary*))))

(let ((range
       (bio:alpha-range
        (car 
         (bio:filter-alignments
          (bio:get-annotations *esr2-nucleotide* :type 'bio:simple-pairwise-alignment)
          'bio:cds)))))
  (with-accessors ((start bio:range-start)
                   (end bio:range-end))
      range
    (bio:residues-string (bio:translate *esr2-nucleotide* :range range))))

;;; xpath tests and what not
(defparameter *esr1-gene-node*
  (bio:fetch (bio:id (car (bio:members *esr1-gene-search*)))
             *entrez-xml-dictionary*
             :database "gene"))

(entrez::stp-document->list *esr1-gene-node*)

(join-xpath-result
 (xpath:evaluate
  (concatenate 'string "Entrezgene-Set"
               "/Entrezgene"
               "/Entrezgene_locus"
               "/Gene-commentary"
               "/Gene-commentary_products"
               "/Gene-commentary[Gene-commentary_type/attribute::value=\"mRNA\"]"
               "/Gene-commentary_accession")
  *esr1-gene-node*))

(join-xpath-result
 (xpath:evaluate
  (concatenate 'string "Entrezgene-Set"
               "/Entrezgene"
               "/Entrezgene_summary")
  *esr1-gene-node*))

(xpath:string-value
 (xpath:evaluate "Entrezgene_summary/text()"
                 (xpath:first-node
                  (xpath:evaluate "Entrezgene-Set/Entrezgene"
                                  *esr1-gene-node*))))

(xpath:string-value
 (xpath:evaluate "Entrezgene-Set/Entrezgene/Entrezgene_summary/text()"
                 *esr1-gene-node*))


(xpath:map-node-set->list
 (lambda (commentary-node)
   (let ((type (xpath:string-value
                (xpath:evaluate
                 "Gene-commentary_type/attribute::value"
                 commentary-node)))
         (accession (xpath:string-value
                     (xpath:evaluate
                      "Gene-commentary_accession/text()"
                      commentary-node))))
     (cons type accession)))
 (xpath:evaluate
  (concatenate 'string "Entrezgene-Set"
               "/Entrezgene"
               "/Entrezgene_locus"
               "/Gene-commentary"
               "/Gene-commentary_products"
               "/Gene-commentary")
  *esr1-gene-node*))

(xpath:map-node-set->list
 (lambda (commentary-node)
   (let ((type (xpath:string-value
                (xpath:evaluate
                 "Gene-commentary_type/attribute::value"
                 commentary-node)))
         (accession (xpath:string-value
                     (xpath:evaluate
                      "Gene-commentary_accession/text()"
                      commentary-node))))
     (when (and (equalp type "mRNA")
                accession)
       (let ((id
              (make-instance 'bio:genbank-accession
                             :accession accession))
             (product
              (make-instance 'bio:gene-product
                             :type type)))
         (bio:add-descriptor product id)
         product))))
 (xpath:evaluate
  (concatenate 'string "Entrezgene-Set"
               "/Entrezgene"
               "/Entrezgene_locus"
               "/Gene-commentary"
               "/Gene-commentary_products"
               "/Gene-commentary")
  *esr1-gene-node*))

(bio:split-string-into-lines (bio:residues-string *esr1-nucleotide*))

(bio:split-string-into-lines
 (bio:residues-string *esr1-protein*))

(defparameter *esr1-nucleotide-node*
  (bio:fetch (bio:id
              (car (bio:get-genbank-accessions 
                    (car (bio:gene-products *esr1-gene*)))))
             *entrez-xml-dictionary*))

(join-xpath-result
 (car (xpath:map-node-set->list
       #'entrez::get-gbseq-feature-nodes
       (xpath:evaluate "GBSet/GBSeq" *esr1-nucleotide-node*))))

(join-xpath-result
 (car (let ((gb-seqs
             (xpath:all-nodes
              (xpath:evaluate "GBSet/GBSeq" *esr1-nucleotide-node*))))
        (mapcar #'(lambda (x) (entrez::get-gbseq-feature-nodes x :type "CDS")) gb-seqs))))

(xpath:map-node-set->list
 #'(lambda (seq)
     (let ((list))
       (xpath:map-node-set->list
        (lambda (feat)
          (push (mapcar
                 #'(lambda (from to)
                     (cons (xpath-protocol:node-text from)
                           (xpath-protocol:node-text to)))
                 (xpath:all-nodes
                  (xpath:evaluate
                   "GBFeature_intervals/GBInterval/GBInterval_from/text()"
                   feat))
                 (xpath:all-nodes
                  (xpath:evaluate
                   "GBFeature_intervals/GBInterval/GBInterval_to/text()"
                   feat)))
                list))
        (entrez::get-gbseq-feature-nodes seq :type "CDS"))
       (nreverse list)))
   (xpath:evaluate "GBSet/GBSeq" *esr1-nucleotide-node*))

(join-xpath-result
 (xpath:evaluate
  "GBSet/GBSeq/*/text()"
  *esr1-nucleotide-node*))

(join-xpath-result
 (xpath:evaluate
  (concatenate 'string "GBSet"
               "/GBSeq"
               "/GBSeq_sequence/text()")
  *esr1-nucleotide-node*))

(join-xpath-result
 (xpath:evaluate
  (concatenate 'string "GBSet"
               "/GBSeq"
               "/GBSeq_feature-table"
               "/GBFeature[GBFeature_key/text()=\"CDS\"]")
  *esr1-nucleotide-node*))

(join-xpath-result
 (xpath:evaluate
  (concatenate 'string "GBSet"
               "/GBSeq"
               "/GBSeq_feature-table"
               "/GBFeature/GBFeature_key/text()")
  *esr1-nucleotide-node*))

;;; genomic
(defparameter *genomic*
  (bio:fetch "BX322656" *entrez-dictionary*))

(defparameter *genomic-bioseq* (car (bio:members *genomic*)))

(bio:split-string-into-lines (bio:residues-string *genomic-bioseq*))


;;; dpp
(defparameter *dpp-gene-search*
  (bio:lookup "dpp" *entrez-dictionary* :database "gene"))

(defparameter *dpp-gene-search-node*
  (bio:lookup "dpp" *entrez-xml-dictionary* :database "gene"))

(entrez::stp-document->list *dpp-gene-search-node*)

(defparameter *dpp-gene-node*
  (bio:fetch (bio:id (car (bio:members *dpp-gene-search*)))
             *entrez-xml-dictionary*
             :database "gene"))

(entrez::stp-document->list *dpp-gene-node*)

(defparameter *dpp-gene*
  (car (bio:members
        (bio:fetch (bio:id (car (bio:members *dpp-gene-search*)))
                   *entrez-dictionary*
                   :database "gene"))))

(defparameter *dpp-nucleotide-search*
  (bio:lookup "dpp" *entrez-dictionary* :database "nucleotide"))

(join-xpath-result (xpath:evaluate
                      (concatenate 'string "Entrezgene-Set"
                                   "/Entrezgene"
                                   "/Entrezgene_locus"
                                   "/Gene-commentary"
                                   "/Gene-commentary_label"
                                   #+nil "/Gene-commentary"
                                   #+nil "/Gene-commentary_accession")
                      *dpp-gene-node*))

(join-xpath-result (xpath:evaluate
                      (concatenate 'string "Entrezgene-Set"
                                   "/Entrezgene"
                                   "/Entrezgene_source"
                                   "/BioSource"
                                   "/BioSource_org"
                                   "/Org-ref"
                                   "/Org-ref_db")
                      *dpp-gene-node*))

(join-xpath-result (xpath:evaluate
                      (concatenate 'string "Entrezgene-Set"
                                   "/Entrezgene"
                                   "/Entrezgene_locus"
                                   "/Gene-commentary"
                                   "/Gene-commentary_products"
                                   "/Gene-commentary"
                                   "/Gene-commentary_type/attribute::value")
                      *dpp-gene-node*))

(join-xpath-result (xpath:evaluate
                      (concatenate 'string "Entrezgene-Set"
                                   "/Entrezgene"
                                   "/Entrezgene_comments"
                                   "/Gene-commentary[*/attribute::value=\"comment\"]"
                                   "/Gene-commentary_refs"
                                   "/Pub"
                                   "/Pub_pmid"
                                   "/PubMedId")
                      *dpp-gene-node*))

(join-xpath-result (xpath:evaluate
                      (concatenate 'string "Entrezgene-Set"
                                   "/Entrezgene"
                                   "/Entrezgene_comments"
                                   "/Gene-commentary[Gene-commentary_type/attribute::value=\"generif\"]")
                      *dpp-gene-node*))

(xpath:string-value
   (xpath:evaluate (concatenate 'string "Entrezgene-Set"
                                "/Entrezgene"
                                "/Entrezgene_type/attribute::value")
                   *dpp-gene-node*))

(xpath:map-node-set->list
 (lambda (node)
   (let ((db (xpath:string-value (xpath:evaluate "Dbtag_db/text()" node)))
         (object-id-id (xpath:string-value
                        (xpath:evaluate "Dbtag_tag/Object-id/Object-id_id/text()"
                                        node)))
         (object-id-str (xpath:string-value
                         (xpath:evaluate "Dbtag_tag/Object-id/Object-id_str/text()"
                                         node))))
     (cons db (if (equal object-id-id "")
                  object-id-str
                  object-id-id))))
 (xpath:evaluate "//Dbtag" *dpp-gene-node*))

(xpath:string-value
 (xpath:evaluate (concatenate 'string "Entrezgene-Set/Entrezgene/Entrezgene_source/BioSource/BioSource_org/Org-ref/Org-ref_taxname/text()")
                 *dpp-gene-node*))

(mapcar #'generif-text
        (bio:get-descriptors *dpp-gene* :type 'generif))

;;; structure?
(defparameter *esr1-search-structure*
  (entrez-search "ESR1" :retmax 10
                 :database "structure"
                 :copy-to-file "data/esr1-search-structure.xml"
                 :builder (cxml-stp:make-builder)))

#+nil
(defparameter *esr1-structure*
  (entrez-fetch "60515"
                :retmode "pdb"
                :database "structure"
                :copy-to-file "data/esr1-structure.xml"
                :builder (cxml-stp:make-builder)))


;;; pubmed

(defparameter *eisen-drosophila-search*
  (bio:lookup "Eisen drosophila" *entrez-dictionary* :database "pubmed"))

(defparameter *eisen-drosophila-paper*
  (let ((pmid (bio:id (car (bio:members entrez-user::*eisen-drosophila-search*)))))
    (car (bio:members (bio:fetch pmid *entrez-dictionary* :database "pubmed")))))

(describe (car (bio:members (bio:fetch "19247932" *entrez-dictionary* :database "pubmed"))))


(let ((pmid (bio:id (car (bio:members
                          (bio:lookup "endoxifen"
                                      *entrez-dictionary*
                                      :database "pubmed"))))))
  (car (bio:members (bio:fetch pmid *entrez-dictionary* :database "pubmed"))))

;;;
"http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi/entrez/eutils/esearch.fcgi?db=gene&term=ESR1+estrogen&retmode=xml&retstart=0&retmax=20"

"http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi/entrez/eutils/esearch.fcgi?db=gene&term=NG_008493%5Baccession%5D&retmode=xml&retstart=0&retmax=20"

(defparameter *esr1-refseqgene-search*
  (bio:lookup "NG_008493[accession]" *entrez-dictionary* :database "nucleotide"))
