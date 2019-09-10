;;;; Generate "index.html" pages for SRFIs

;; This runs on MIT Scheme.

(declare (usual-integrations))

(load-option 'format)

(define (read-entire-file pathname)
  (with-input-from-file pathname
    (lambda ()
      (with-output-to-string
	(lambda ()
	  (let loop ()
	    (let ((char (read-char)))
	      (cond ((not (eof-object? char))
		     (write-char char)
		     (loop))))))))))

(define (parse-template string)
  (let ((size (string-length string)))
    (let loop ((accumulator '())
	       (index 0))
      (let ((start (substring-search-forward "<*<" string index size)))
	(if start
	    (let ((end (substring-search-forward ">*>"
						 string
						 (+ index 3)
						 size)))
	      (if end
		  (loop (cons* (string->symbol
				(substring string (+ start 3) end))
			       (substring string index start)
			       accumulator)
			(+ end 3))
		  (error "Missing variable end." index)))
	    (reverse! (cons (substring string index size)
			    accumulator)))))))

(define (read-template pathname)
  (parse-template (read-entire-file pathname)))

(define (invoke-template template variables)
  (do ((template template (cdr template)))
      ((null? template))
    (let ((element (car template)))
      (cond ((string? element) (write-string element))
	    ((symbol? element)
	     (let ((association (assq element variables)))
	       (if association
		   (display (cadr association))
		   (error "Missing variable." element))))))))

(define (invoke-template/string template variables)
  (with-output-to-string
    (lambda ()
      (invoke-template template variables))))

(define faq-anchor-template
  (read-template "srfi-common/admin/faq-anchor.template"))

(define home-template (read-template "srfi-common/admin/home.template"))

(define keyword-option-template
  (read-template "srfi-common/admin/keyword-option.template"))

(define see-also-html-template
  (read-template "srfi-common/admin/see-also-html.template"))

(define see-also-text-template
  (read-template "srfi-common/admin/see-also-text.template"))

(define srfi-card-template
  (read-template "srfi-common/admin/srfi-card.template"))

(define index-template (read-template "srfi-common/admin/index.template"))
(define archive-simplelists-template
  (read-template "srfi-common/admin/archive-simplelists.template"))
(define readme-template (read-template "srfi-common/admin/readme.template"))

(define srfi-anchor-template
  (read-template "srfi-common/admin/srfi-anchor.template"))

(define srfi-list-subscribe-template
  (read-template "srfi-common/admin/srfi-list-subscribe.template"))

(define srfi-list-template
  (read-template "srfi-common/admin/srfi-list.template"))

(define (srfi-date-to-show srfi)
  (case (srfi/status srfi)
    ((draft) (srfi/draft-date srfi))
    ((final) (srfi/done-date srfi))
    ((withdrawn) (srfi/done-date srfi))
    (else (error "Unknown status."))))

(define (srfi-abstract n)
  (read-entire-file
   (format #f "$ss/srfi-common/admin/abstracts/~A.html" n)))

(define (write-single-srfi-index-page srfi)
  (let* ((number (srfi/number srfi))
	 (abstract (srfi-abstract number))
	 (archives
	  (invoke-template/string
	   archive-simplelists-template
	   `((number ,number)
	     (prefix ""))))
	 (date (srfi-date-to-show srfi))
	 (status (srfi/status srfi))
	 (title (srfi/title srfi))
	 (authors (srfi/authors srfi))
	 (pathname (format #f "srfi-~A/index.html" number)))
    (with-output-to-file pathname
      (lambda ()
	(invoke-template index-template
			 `((abstract ,abstract)
			   (authors ,authors)
			   (date ,date)
			   (email-archives ,archives)
			   (number ,number)
			   (see-also ,(see-also-html srfi))
			   (status ,status)
			   (title ,title)))))))

(define (see-also-text srfi)
  (define (srfi-link srfi)
    (let ((n (srfi/number srfi)))
      (format #f
	      "[[https://srfi.schemers.org/srfi-~A/][SRFI ~A: ~A]]"
	      n
	      n
	      (srfi/title srfi))))
  (let ((others (srfi/see-also srfi)))
    (if (null? others)
	""
	(invoke-template/string
	 see-also-text-template
	 `((srfis
	    ,(string-join-english
	      (map (lambda (n) (srfi-link (srfi-assoc n srfis)))
		   (sort others <)))))))))

(define (write-single-srfi-readme srfi)
  (let* ((number (srfi/number srfi))
	 (status (srfi/status srfi))
	 (title (srfi/title srfi))
	 (authors (srfi/authors srfi))
	 (pathname (format #f "srfi-~A/README.org" number)))
    (with-output-to-file pathname
      (lambda ()
	(invoke-template readme-template
			 `((authors ,authors)
			   (number ,number)
			   (see-also ,(see-also-text srfi))
			   (status ,status)
			   (title ,title)))))))

(define (write-srfi-index-pages)
  (if (not (file-directory? "srfi-0"))
      (error "Working directory must contain all SRFI directories."))
  (do ((srfis srfis (cdr srfis)))
      ((null? srfis))
    (write-single-srfi-index-page (car srfis))))

(define (write-srfi-readmes)
  (if (not (file-directory? "srfi-0"))
      (error "Working directory must contain all SRFI directories."))
  (do ((srfis srfis (cdr srfis)))
      ((null? srfis))
    (write-single-srfi-readme (car srfis))))

(define (status->name status)
  (case status
    ((draft) "Draft")
    ((final) "Final")
    ((withdrawn) "Withdrawn")
    (else (error "Unknown status."))))

(define (faq-anchor-fragment name description)
  (invoke-template/string
   faq-anchor-template
   `((description ,description)
     (name ,name))))

(define (srfi-anchor-fragment srfi)
  (invoke-template/string
   srfi-anchor-template
   `((number ,(number->string (srfi/number srfi)))
     (title ,(srfi/title srfi)))))

(define (string-join-english string-list)
  "Return a string constructed by appending the elements of
`string-list', separating them with \", \" except for the last pair,
which should be separated by \" and\" if there are only two elements
and \", and\" otherwise."
  (cond ((null? string-list) "")
	((null? (cdr string-list)) (car string-list))
	((null? (cddr string-list))
	 (string-append (car string-list)
			" and "
			(cadr string-list)))
	(else
	 (with-output-to-string
	   (lambda ()
	     (let next ((remaining string-list))
	       (write-string (car remaining))
	       (cond ((null? (cddr remaining))
		      (write-string ", and ")
		      (write-string (cadr remaining)))
		     (else (write-string ", ")
			   (next (cdr remaining))))))))))

(define (see-also-html srfi)
  (let ((others (srfi/see-also srfi)))
    (if (null? others)
	""
	(invoke-template/string
	 see-also-html-template
	 `((srfis
	    ,(string-join-english
	      (map (lambda (n) (srfi-anchor-fragment (srfi-assoc n srfis)))
		   (sort others <)))))))))

(define (keyword->name value)
  (let ((a (assoc value srfi-keywords)))
    (assert a "No such keyword.")
    (cadr a)))

(define (write-srfi-card srfi)
  (let ((n (srfi/number srfi))
	(keywords (srfi/keywords srfi))
	(status (srfi/status srfi)))
    (invoke-template
     srfi-card-template
     `((abstract ,(srfi-abstract n))
       (authors ,(srfi/authors srfi))
       (date ,(srfi-date-to-show srfi))
       (date-type ,(status->name status))
       (keyword-names ,(string-join ", " (map keyword->name keywords)))
       (keyword-values ,(string-join "," keywords))
       (name ,(srfi/title srfi))
       (number ,n)
       (see-also ,(see-also-html srfi))
       (status ,status)))))

(define (keyword-options)
  (with-output-to-string
    (lambda ()
      (do-list (k srfi-keywords)
	(invoke-template
	 keyword-option-template
	 `((name ,(cadr k))
	   (value ,(car k))))))))

;; Note that this generates "index.html", which is separate from the
;; "README.org" page.
(define (write-srfi-home-page)
  (let ((srfi-list
	 (with-output-to-string
	   (lambda ()
	     (for-each write-srfi-card (reverse srfis))))))
    (with-output-to-file "$ss/srfi-common/index.html"
      (lambda ()
	(invoke-template home-template
			 `((keyword-options ,(keyword-options))
			   (srfi-list ,srfi-list)))))))

(define (write-srfi-subscribe-form name description)
  (with-output-to-string
    (lambda ()
      (invoke-template srfi-list-template
		       `((description ,description)
			 (name ,name))))))

(define (write-srfi-list-subscribe-page)
  (with-output-to-file "$ss/srfi-common/srfi-list-subscribe.html"
    (lambda ()
      (invoke-template
       srfi-list-subscribe-template
       `((announce
	  ,(write-srfi-subscribe-form
	    "srfi-announce"
	    "This is a moderated mailing list where all announcements about new SRFI proposals and changes in status are posted."))
	 (discuss
	  ,(write-srfi-subscribe-form
	    "srfi-discuss"
	    "This is an unmoderated mailing list for general discussion of the SRFI process.  It is archived <a href=\"https://srfi-email.schemers.org/srfi-discuss\">here</a>."))
	 (srfi-auto-subscribe
	  ,(write-srfi-subscribe-form
	    "srfi-auto-subscribe"
	    "Subscribe to this list if you'd like to receive messages from <a href=\"#srfi-announce\"><code>srfi-announce</code></a>, <a href=\"#srfi-discuss\"><code>srfi-discuss</code></a>, and all <a href=\"#srfi-n\">srfi-<em>n</em></a> discussion mailing lists.  Note that this list does <em>not</em> deliver messages from <a href=\"#schemedoc\"><code>schemedoc</code></a>, <a href=\"#schemepersist\"><code>schemepersist</code></a>, or <a href=\"#schemeweb\"><code>schemeweb</code></a>.  You can subscribe to them independently."))
	 (schemedoc
	  ,(write-srfi-subscribe-form
	    "schemedoc"
	    "This is an unmoderated discussion of collecting, organizing, and serving indexes of Scheme code found in SRFIs, Scheme implementations, R<sup>n</sup>RS standards, etc."))
	 (schemepersist
	  ,(write-srfi-subscribe-form
	    "schemepersist"
	    "This is an unmoderated discussion of persistent storage for Scheme implementations, including existing, new, and improved persistence libraries; interface protocols to support; SRFIs to write; etc."))
	 (schemeweb
	  ,(write-srfi-subscribe-form
	    "schemeweb"
	    "This is an unmoderated discussion of web technology implemented in Scheme, e.g. web servers and web request handlers.")))))))