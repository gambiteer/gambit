;;;===========================================================================

;;; File: "_expand.scm"

;;; Copyright (c) 2024 by Marc Feeley, All Rights Reserved.
;;; Copyright (c) 2024 by Antoine Doucet, All Rights Reserved.

;;;============================================================================

;;; TODO: fill environment with global primitives
(define ##allow-unbound? #t)

(define (##allow-unbound?-set! b)
  (set! ##allow-unbound? b))

;;;----------------------------------------------------------------------------
;;; make forms

(define-primitive (make-core-form form . args)
  (plain-datum->syntax
    `(,(make-core-syntax-source form #f)
      ,@(let loop ((args args))
          (let ((arg (car args))
                (args (cdr args)))
            (cond
              ((null? args)
               (cond
                 ((pair? arg)
                  arg
                  (list arg))
              (cons arg (loop args))))))))))

(define-primitive (make-letrec*-form bindings body)
  (##make-core-form '##letrec* bindings body))

(define-primitive (make-begin-form body)
  (##make-core-form '##begin body))

(define-primitive (make-lambda-form args body)
  (##make-core-form '##lambda args body))

;;;----------------------------------------------------------------------------
;;; binding registration
;;;
;;; Those forms can be generalized into one, avoiding some code repetion,
;;; but, splitting them seems more readable.

(define (expand-let-bindings bindings-src cte)
  (let ((scps (list (make-scope))))
    (let loop ((bindings bindings-src)
               (res      '())
               (cte      cte))
      (match-source bindings ()
        ((binding @ (id val) . bindings)
         (let ((id  (add-scope id (car scps)))
               (val (expand val cte)))
           (cond
             ((or (pair? (syntax-source-code id))
                  (null? (syntax-source-code id)))
              (let loop-ids ((ids  (syntax-source-code id))
                             (cte cte))
                (cond
                  ((pair? ids)
                   (let* ((key (hcte-add-new-local-binding! cte (car ids)))
                          (cte (hcte-add-variable-cte cte key (car ids))))
                     (loop-ids
                       (cdr ids)
                       cte)))
                  ((null? ids)
                   (let ((binding (syntax-source-code-set binding (list id val))))
                     (loop 
                       bindings
                       (cons binding res)
                       cte)))
                  (else
                   (let* ((key (hcte-add-new-local-binding! cte ids))
                          (cte (hcte-add-variable-cte cte key ids)))
                     (let ((binding (syntax-source-code-set binding (list id val))))
                       (loop 
                         bindings
                         (cons binding res)
                         cte)))))))

             (else
               (let* ((key (hcte-add-new-local-binding! cte id))
                      (cte (hcte-add-variable-cte cte key id))
                      (binding (syntax-source-code-set binding
                                 (list id val))))
                 (loop 
                   bindings
                   (cons binding res)
                   cte))))))
        (_
          (list scps 
                (syntax-source-code-set bindings-src
                  (reverse res))
                cte))))))

(define (expand-let*-bindings bindings-src cte)
  (let ((scps (list)))
    (let loop ((bindings bindings-src)
               (res      '())
               (scps     scps)
               (cte      cte))
      (match-source bindings ()
        ((binding @ (id val) . bindings)
         (let* ((val (expand (add-scopes val scps) cte))
                (scps (cons (make-scope) scps))
                (id (add-scopes id scps)))
           (cond
             ((or (pair? (syntax-source-code id))
                  (null? (syntax-source-code id)))
              (let loop-ids ((ids (syntax-source-code id))
                             (cte cte))
                (cond 
                  ((pair? ids)
                   (let* ((key (hcte-add-new-local-binding! cte (car ids)))
                          (cte (hcte-add-variable-cte cte key (car ids))))
                     (loop-ids
                       (cdr ids)
                       cte)))
                  ((null? ids)
                   (let ((binding (syntax-source-code-set binding (list id val))))
                     (loop
                       bindings
                       (cons binding res)
                       scps
                       cte)))
                  (else
                   (let* ((key (hcte-add-new-local-binding! cte ids))
                          (cte (hcte-add-variable-cte cte key ids)))
                     (let ((binding (syntax-source-code-set binding (list id val))))
                       (loop
                         bindings
                         (cons binding res)
                         scps
                         cte)))))))
             (else
               (let* ((key (hcte-add-new-local-binding! cte id))
                      (cte (hcte-add-variable-cte cte key id))
                      (binding (syntax-source-code-set binding
                                 (list id val))))
                 (loop
                   bindings
                   (cons binding res)
                   scps
                   cte))))))
        (_
          (list scps 
                (syntax-source-code-set bindings-src
                  (reverse res)) 
                cte))))))

(define (expand-letrec-bindings bindings-src cte)
  (let ((scps (list (make-scope))))
    (let loop ((bindings bindings-src)
               (res      '())
               (cte      cte))
      (match-source bindings ()
        ((binding @ (id val) . bindings)
         (let ((id (add-scope id (car scps))))
           (cond
            ((or (pair? (syntax-source-code id))
                 (null? (syntax-source-code id)))
             (let loop-ids ((ids (syntax-source-code id))
                            (cte cte))
               (cond
                 ((pair? ids)
                  (let* ((key (hcte-add-new-local-binding! cte (car ids)))
                         (cte (hcte-add-variable-cte cte key (car ids))))
                    (loop-ids
                      (cdr ids)
                      cte)))
                 ((null? ids)
                  (let* ((val (add-scope val (car scps)))
                         (binding (syntax-source-code-set binding
                                    (list id val))))
                    (loop 
                      bindings
                      (cons binding res)
                      cte)))
                 (else
                  (let* ((key (hcte-add-new-local-binding! cte ids))
                         (cte (hcte-add-variable-cte cte key ids)))
                    (let* ((val (add-scope val (car scps)))
                           (binding (syntax-source-code-set binding
                                      (list id val))))
                      (loop 
                        bindings
                        (cons binding res)
                        cte)))))))
            (else
             (let* ((key (hcte-add-new-local-binding! cte id))
                    (cte (hcte-add-variable-cte cte key id))
                    (val (add-scope val (car scps)))
                    (binding (syntax-source-code-set binding
                               (list id val))))
               (loop 
                 bindings
                 (cons binding res)
                 cte))))))
        (_
          (let ((bindings (let loop ((bindings res)
                                     (result   (list)))
                            (cond
                              ((pair? bindings)
                               (let ((binding (car bindings)))
                                 (let ((new-binding
                                         (syntax-source-code-update binding
                                           (lambda (binding-code)
                                             (match-source binding-code ()
                                               ((id val)
                                                (list id (expand val cte))))))))
                                   (loop 
                                     (cdr bindings)
                                     (cons new-binding result)))))
                              (else
                                result)))))
            (list scps (syntax-source-code-set bindings-src bindings) cte)))))))

(define (expand-letrec*-bindings bindings-src cte)
  (expand-letrec-bindings bindings-src cte))

(define (expand-let-syntax-bindings bindings-src cte)
  (let ((original-cte cte))
    (let ((scps (list (make-scope))))
      (let loop ((bindings bindings-src)
                 (cte      cte))
        (match-source bindings ()
          ((binding @ (id val) . bindings)
           (let ((id  (add-scope id (car scps)))
                 (val (##eval-for-syntax-binding val original-cte)))
             (let* ((key (hcte-add-new-local-binding! cte id))
                    (cte (hcte-add-macro-cte cte key id val)))
               (loop 
                 bindings
                 cte))))
          (_
           (list scps 
                 #f
                 cte)))))))

(define (expand-let*-syntax-bindings bindings-src cte)
  (let ((scps (list)))
    (let loop ((bindings bindings-src)
               (res      '())
               (scps     scps)
               (cte      cte))
      (match-source bindings ()
        ((binding @ (id val) . bindings)
         (let* ((val (##eval-for-syntax-binding
                       (add-scopes val scps) 
                       cte))
                (scps (cons (make-scope) scps))
                (id (add-scopes id scps)))
           (let* ((key (hcte-add-new-local-binding! cte id))
                  (cte (hcte-add-macro-cte cte key id val))
                  (binding (syntax-source-code-set binding
                             (list id val))))
             (loop
               bindings
               (cons binding res)
               scps
               cte))))
        (_
          (list scps 
                (syntax-source-code-set bindings-src
                  (reverse res)) 
                cte))))))

(define (expand-letrec-syntax-bindings bindings-src cte)
  (let ((original-cte cte)
        (scps (list (make-scope))))
    (let loop ((bindings bindings-src)
               (cte      cte))
      (match-source bindings ()
        ((binding @ (id val) . bindings)
         (let ((id  (add-scope id (car scps)))
               (val (add-scope val (car scps)))
               (fake-val (lambda _ 'dummy)))
           (let* ((key (hcte-add-new-local-binding! cte id))
                  (original-cte (hcte-add-macro-cte original-cte key id fake-val))
                  (val (##eval-for-syntax-binding val original-cte))
                  (cte (hcte-add-macro-cte cte key id val)))
             (loop 
               bindings
               cte))))
        (_
          (list scps 
                #f
                cte))))))

(define (expand-letrec*-syntax-bindings bindings-src cte)
  (let ((scps (list)))
    (let loop ((bindings bindings-src)
               (res      '())
               (scps     scps)
               (cte      cte))
      (match-source bindings ()
        ((binding @ (id val) . bindings)
         (let* ((fake-val (lambda _ 'dummy))
                (scps (cons (make-scope) scps))
                (id (add-scopes id scps)))
           (let* ((key (hcte-add-new-local-binding! cte id))
                  (cte (hcte-add-macro-cte cte key id fake-val))
                  (val (##eval-for-syntax-binding
                       (add-scopes val scps) 
                       cte))
                  (cte (hcte-add-macro-cte cte key id val))
                  (binding (syntax-source-code-set binding
                             (list id val))))
             (loop
               bindings
               (cons binding res)
               scps
               cte))))
        (_
          (list scps 
                (syntax-source-code-set bindings-src
                  (reverse res)) 
                cte))))))

(define-macro (expand-let-forms head syntax? stx cte)

  (define expand-bindings
    (case head 
      ((##let)            'expand-let-bindings)
      ((##let*)           'expand-let*-bindings)
      ((##letrec)         'expand-letrec-bindings)
      ((##letrec*)        'expand-letrec*-bindings)
      ((##let-syntax)     'expand-let-syntax-bindings)
      ((##let*-syntax)    'expand-let*-syntax-bindings)
      ((##letrec-syntax)  'expand-letrec-syntax-bindings)
      ((##letrec*-syntax) 'expand-letrec*-syntax-bindings)
      ((##let-values)     'expand-let-bindings)
      ((##let*-values)    'expand-let*-bindings)
      ((##letrec-values)  'expand-letrec-bindings)
      ((##letrec*-values) 'expand-letrec*-bindings)
      (else               (error "Internal: cannot process let form's bindings"))))

  (let ((stx-id (##gensym 'stx)))
   `(let ((,stx-id ,stx))
      (match-source ,stx-id ()
        ((let-id name bindings . body) when (identifier? name)
         (let* ((fake-binding  (##make-syntax-source `(,name ,(##make-syntax-source #f #f)) #f))
                (fake-bindings (syntax-source-code-update bindings 
                                 (lambda (code) (cons fake-binding code))))
                (fake-expr     (syntax-source-code-set ,stx-id
                                `(,(##make-core-syntax-source '##let* #f) ,fake-bindings ,@body))))
           (match-source (expand fake-expr cte) ()
             ((_ ((name _) . bindings) . body)
              (syntax-source-code-set ,stx-id
                `(,let-id ,name ,(##make-syntax-source bindings #f) ,@body)))
             (_ (error "internal")))))
        ((let-id bindings . body)
         (let* ((scps+bindings+cte (,expand-bindings bindings ,cte))
                (scps     (car scps+bindings+cte))
                (bindings (cadr scps+bindings+cte))
                (cte      (caddr scps+bindings+cte))
                (body (expand-body body cte scps)))
           ,(cond
             (syntax?
               `(syntax-source-code-set ,stx-id
                 (cons (##make-core-syntax-source '##begin #f) body)))
             (else
               `(syntax-source-code-set ,stx-id
                 `(,let-id ,bindings ,@body))))))
        (_
          (error "ill-formed let form"))))))

(define-prim&proc (expand-let stx cte)
  (expand-let-forms ##let #f stx cte))

(define-prim&proc (expand-let* stx cte)
  (expand-let-forms ##let* #f stx cte))

(define-prim&proc (expand-letrec stx cte)
  (expand-let-forms ##letrec #f stx cte))

(define-prim&proc (expand-letrec* stx cte)
  (expand-let-forms ##letrec* #f stx cte))

(define-prim&proc (expand-let-values stx cte)
  (expand-let-forms ##let-values #f stx cte))

(define-prim&proc (expand-let*-values stx cte)
  (expand-let-forms ##let*-values #f stx cte))

(define-prim&proc (expand-letrec-values stx cte)
  (expand-let-forms ##letrec-values #f stx cte))

(define-prim&proc (expand-letrec*-values stx cte)
  (expand-let-forms ##letrec*-values #f stx cte))

(define-prim&proc (expand-let-syntax stx cte)
  (expand-let-forms ##let-syntax #t stx cte))

(define-prim&proc (expand-let*-syntax stx cte)
  (expand-let-forms ##let*-syntax #t stx cte))

(define-prim&proc (expand-letrec-syntax stx cte)
  (expand-let-forms ##letrec-syntax #t stx cte))

(define-prim&proc (expand-letrec*-syntax stx cte)
  (expand-let-forms ##letrec*-syntax #t stx cte))

;;;----------------------------------------------------------------------------

(define (expand->core-form stx cte)
  (match-source stx ()
    ((id . exprs) when (identifier? id)
     (let ((t (##resolve-binding-expander id cte)))
       (if (or (not (##vector? t))
               (##not-found-object? t))
           stx
           (##dispatch t stx cte #t))))
    (_ stx)))

(define-prim&proc (expand-begin s cte)
  (match-source s ()
    ((##begin-id . exprs)
     (syntax-source-code-set s
       (cons ##begin-id
             (syntax-source-code
               (##expand-pair/list (syntax-source-code-set s exprs) cte 
                 (lambda _ 
                   (##pretty-print s)
                   (error "expand-begin error")
                   #;(##error-expansion ##expand-begin s "Ill formed begin form")))))))
    (_
     (##error-expansion ##expand-begin s "Ill formed begin form"))))

(define-prim&proc (expand-body body cte scps)
  ; `letrec*` the variables and macros but disallow mutually exclusive bindings.
  ; The full letrec* behavior can be allowed by expanding macro definition
  ; to a core-form, using a let* behavior for variables and macros used, 
  ; and then binding every variable into a letrec* form. Then, it should
  ; be easier to break hygiene to include definer macros.

  (let ((scps (cons (make-scope) scps)))
    (let loop ((bindings body)
               (res      '())
               (scps     scps)
               (cte      cte))
      (match-source bindings ()
        ((binding . bindings)
         (let ((core-expanded-binding (expand->core-form binding cte)))
           (let match ((core-expanded-binding core-expanded-binding))
             (match-source core-expanded-binding (##define ##define-syntax ##define-top-level-syntax)
               ((##define (id . args) . rest)
                (match (##transform-define-form->base-form core-expanded-binding)))
               ((##define id val)
                (let ((definer (car (syntax-source-code core-expanded-binding))))
                  (let* ((scps scps)
                         (id   (add-scopes id scps))
                         (key  (hcte-add-new-local-binding! cte id))
                         (cte  (hcte-add-variable-cte cte key id))
                         (val  (add-scopes val scps))
                         (binding (syntax-source-code-set core-expanded-binding (list definer id val))))
                    (loop
                      bindings
                      (cons binding res)
                      scps
                      cte))))
               ((##define-top-level-syntax id val)
                (##expand-define-syntax core-expanded-binding cte)
                (loop
                  bindings
                  res
                  scps
                  cte))
               ((##define-syntax id val)
                (let ((definer (car (syntax-source-code core-expanded-binding))))
                  (let* ((fake-val (lambda _ 'dummy))
                         (scps     scps)
                         (id       (add-scopes id scps))
                         (key      (hcte-add-new-local-binding! cte id))
                         (cte      (hcte-add-macro-cte cte key id fake-val))
                         (val      (##eval-for-syntax-binding
                                     (add-scopes val scps)
                                     cte))
                         (cte      (hcte-add-macro-cte cte key id val))
                         (binding  (syntax-source-code-set core-expanded-binding 
                                     (list definer id val))))
                    (loop
                      bindings
                      res 
                      scps
                      cte))))
               (rest
                 (let ((defs (map (lambda (orig-binding binding)
                                        (match-source binding (##define ##define-syntax)
                                          ((##define id val)
                                           (let ((definer (car (syntax-source-code binding))))
                                             (syntax-source-code-set binding
                                                 (list definer
                                                       id
                                                       (expand val cte)))
                                             #;(##transform-define-form->sugar-form
                                               (syntax-source-code-set binding
                                                 (list definer
                                                       id
                                                       (expand val cte)))
                                               orig-binding)))
                                          (else
                                           binding)))
                                      body 
                                      res)))
                         (append
                           (reverse defs)
                           (syntax-source-code
                             (##expand-pair/list (add-scopes
                                                   (syntax-source-code-set (make-syntax-source #f #f)
                                                     (cons binding bindings))
                                                   scps)
                                               cte
                                               (lambda _ 
                                                 (##error-expansion ##expand-body body "Ill formed body form")))))))))))))))
    
;;;----------------------------------------------------------------------------
;;; Sequencing forms

(define-primitive (map-pair proc on-pair-proc p)
  (cond
    ((pair? p)
     (cons (proc (car p))
           (##map-pair proc on-pair-proc (cdr p))))
    ((null? p)
     p)
    (else
     (on-pair-proc p))))

(define-primitive (expand-pair/list stx cte on-pair-proc)
  (syntax-source-code-update stx
    (lambda (code)
      (##map-pair (lambda (e) (expand e cte))
                  on-pair-proc
                  code))))

(define-primitive (expand-pair stx cte)
  (##expand-pair/list stx cte 
    (lambda (code)
      (expand code cte))))

;;;----------------------------------------------------------------------------
;;; application form

(define-primitive (apply-transformer t (stx syntax))
  (let* ((intro-scope (make-scope))
         (intro-stx   (add-scope stx intro-scope)))
    (let ((transformed-stx (t intro-stx)))
      (cond
        ((syntax-source? transformed-stx)
         (flip-scope transformed-stx intro-scope))
        (else
          (error "Macro application's result is not a syntax-source"))))))

(define (##dispatch t s cte #!optional (no-reexpansion #f))
  (cond 
    ((##ctx-binding-variable? t)
     s)
    ((##ctx-binding-macro? t)
     (let* ((descr (##ctx-binding-macro-expander t))
            (proc  descr)) ; TODO reimplement use of gambit descrs
       (let ((transformed-s (##apply-transformer proc s)))
         (if no-reexpansion 
             (expand->core-form transformed-s cte)
             (expand transformed-s cte)))))
    ((##ctx-binding-core-macro? t)
     (cond
       (no-reexpansion
        s)
       (else
         (let ((descr (##ctx-binding-core-macro-expander t))
               (proc  descr)) ; TODO reimplement use of gambit descrs
           (descr s cte)))))
    (else
     (##error-expansion "illegal use of syntax"))))

(define-primitive (expand-id-application-form id stx cte)
  (let ((id (or (syntax-full-name cte id) id)))
    (let ((t (##resolve-binding-expander id cte)))
      (if (or (not (##vector? t))
              (##not-found-object? t))
          (##expand-application stx cte)
          (##dispatch t stx cte)))))

(define-primitive (expand-application stx cte)
  (##expand-pair/list stx cte 
      (lambda (_) 
        (error "non-list application form"))))

#;(define-primitive (expand-keyword-argument stx cte)
  (let ((id  
          (cond
            ((keyword? (syntax-source-code stx))
             (keyword->identifier stx))
            (else
             (error "internal")))))
    (identifier->keyword (##expand-identifier id cte))))

;;;----------------------------------------------------------------------------
;;; lambda

(define-primitive (expand-lambda stx cte)

  (define (register-variable id cte)
    (let* ((key (hcte-add-new-local-binding! cte id))
           (cte (hcte-add-variable-cte cte key id)))

      (list id cte)))

  (define (expand-lambda-bindings bindings scp cte)
    ; -> (bindings cte)

    (define (expand-required-parameters params cte)
      (let loop ((params (add-scope params scp))
                 (res    (list))
                 (cte    cte))
        (cond
          ((pair? params)
           (let* ((id+cte (register-variable (car params) cte))
                  (id     (car id+cte))
                  (cte    (cadr id+cte)))
             (loop
               (cdr params)
               (cons id res)
               cte)))
          (else
           (list (reverse res) cte)))))

    (define (expand-valued-parameters params cte #!optional (keyword-arguments? #f))
      (cond
        (params
          (let loop ((params params)
                     (res    (list))
                     (cte    cte))
            (cond
              ((pair? params)
               (let* ((param (car params))
                      (id    (add-scope (car param) scp))
                      (val   (let ((val (cdr param)))
                               (if (##syntax-source? val)
                                   (expand val cte)
                                   val)))
                      (id+cte (if keyword-arguments?
                                  (register-keyword-variable id cte)
                                  (register-variable id cte)))
                      (id     (car id+cte))
                      (cte    (cadr id+cte)))
                 (loop
                   (cdr params)
                   (cons (list id val) res)
                   cte)))
              (else
                (list (reverse res) cte)))))
        (else
         (list params cte))))

    (define (expand-rest-parameter param cte)
      (or (and param
              (let* ((res+cte (expand-required-parameters (list param) cte))
                     (id      (car (car res+cte)))
                     (cte     (cadr res+cte)))
                (list id cte)))
          (list param cte)))

    (cond
      ((identifier? bindings)
       (let ((bindings (add-scope bindings scp)))
         (register-variable bindings cte)))
      (else
        (let* ((all-parms
                 (##extract-parameters stx bindings))
               (required-parameters
                 (##vector-ref all-parms 0))
               (optional-parameters
                 (##vector-ref all-parms 1))
               (rest-parameter
                 (##vector-ref all-parms 2))
               (dsssl-style-rest?
                 (##vector-ref all-parms 3))
               (key-parameters
                 (##vector-ref all-parms 4)))

          (let* ((required-parameters+cte 
                   (expand-required-parameters required-parameters cte))
                 (required-parameters (car required-parameters+cte))
                 (cte                 (cadr required-parameters+cte))
                 (optional-parameters+cte
                   (expand-valued-parameters optional-parameters cte))
                 (optional-parameters (car optional-parameters+cte))
                 (cte                 (cadr optional-parameters+cte))
                 (key-parameters+cte
                   (expand-valued-parameters key-parameters cte #t))
                 (key-parameters      (car key-parameters+cte))
                 (cte                 (cadr key-parameters+cte))
                 (rest-parameter+cte
                   (expand-rest-parameter rest-parameter cte))
                 (rest-parameter      (car rest-parameter+cte))
                 (cte                 (cadr rest-parameter+cte)))

            (list
              (##reconstruct-parameters 
                bindings
                required-parameters
                optional-parameters
                rest-parameter
                dsssl-style-rest?
                key-parameters)
              cte))))))
  (let ((scp (make-scope)))
    (match-source stx ()
      ((lambda-id bindings . body)
       (let* ((bindings+cte (expand-lambda-bindings bindings scp cte))
              (bindings         (car  bindings+cte))
              (cte              (cadr bindings+cte)))
         (let ((body (##expand-body body cte (list scp))))
           (syntax-source-code-set stx
             `(,lambda-id ,bindings ,@body))))))))

;;;----------------------------------------------------------------------------
;;; top-level definition forms

(define-primitive (transform-define-form->base-form stx)
  ; desugar define forms
  (match-source stx ()
    ((define-id (id . args) . body)
     (syntax-source-code-set stx
      `(,define-id ,id ,(syntax-source-code-set stx
                          `(,(##make-core-syntax-source '##lambda #f)
                            ,(if (identifier? args)
                                 args
                                 (syntax-source-code-set stx args))
                            ,@body)))))
    ((define-id id val)
     stx)
    (_
      (##error-expansion ##transform-define-form->base-form stx "ill-formed define form:"))))

(define-primitive (transform-define-form->sugar-form stx original-stx)
  ; reconstruct a sugared define-form

  (match-source original-stx ()
    ((_ binding @ (_ . _) . _)
     ; sugar form 
     ;
     (match-source stx ()
       ((define-id id (lambda-id args . body))
        (syntax-source-code-set original-stx 
          `(,define-id ,(syntax-source-code-set binding 
                          (cons id (if (identifier? args)
                                       args
                                       (syntax-source-code args))))
                       ,@body)))))
    (_
     ; base form
     ;
      stx)))

(define-prim&proc (syntax-full-name cte id)
  (let ((name (syntax-source-code id)))
    (if (##full-name? name)
        id
        (let ((full-name (let loop ((cte (##top-cte-cte cte)))
                           (cond
                             ((##cte-top? cte)
                              (##vector 'var name))
                             ((##cte-namespace? cte)
                              (##vector 'var (##make-full-name 
                                              (##cte-namespace-prefix cte)
                                              name)))
                             (else
                              (loop (##cte-parent-cte cte)))))))
          (case (##vector-ref full-name 0)
            ((not-found)
             #f)
            ((var) (syntax-source-code-set id
                     (##vector-ref full-name 1)))
            (else  (##raise-expression-parsing-exception
                    'macro-used-as-variable
                    id 
                    name)))))))

(define-prim&proc (expand-define stx cte)
  (cond
    ((##cte-top? cte)
     (match-source (##transform-define-form->base-form stx) ()
      ((define-id id val)
       (let ((full-id (or (syntax-full-name cte id) id)))
         (let* ((_   (hcte-add-new-top-level-binding! cte full-id))
                (val (##expand val cte))
                (expanded-stx (syntax-source-code-set stx 
                                 `(,define-id ,full-id ,val))))
           (##transform-define-form->sugar-form expanded-stx stx))))))
    (else
      (##error-expansion ##expand-define stx "ill-placed define"))))

(define-primitive (expand-define-syntax stx cte)
  (cond
    ((##cte-top? cte)
     (match-source stx ()
      ((define-id id expander)
       (let ((id (or (syntax-full-name cte id) id)))
         (top-hcte-add-macro-cte! cte id (lambda _ (##make-syntax-source 'dummy #f)))
         (let ((descr (##eval-for-syntax-binding expander cte)))
           (top-hcte-add-macro-cte! cte id descr)
           (syntax-source-code-set stx #!void))))))
    (else
      (##error-expansion ##expand-define-syntax stx "ill-placed define-syntax"))))

(define-primitive (expand-define-top-level-syntax stx cte)
  ; only called at top-level
  (##expand-define-syntax stx cte))

;;;----------------------------------------------------------------------------

(define-primitive (expand-identifier id cte)
  (let ((id (or (syntax-full-name cte id) id)))
    (let ((binding (resolve-local (syntax-full-name cte id) cte)))
      (let ((key 
              (cond
                ((##binding-top-level? binding)
                 (##binding-top-level-symbol binding))
                ((##binding-local? binding)
                 (##binding-local-key binding))
                (else
                 #f))))
        (let ((value (and key (##cte-ctx-ref cte key))))
          (cond
            ((and value 
                  (##ctx-binding-variable? value))
             id)
            (value
             (##error-expansion ##expand-identifier id "macro name can't be used as variable"))
            ((and binding (##binding-top-level? binding))
             id)
            (##allow-unbound?
             id)
            (else
              (##error ##expand-identifier id  binding key value "unbound identifier"))))))))

;;;----------------------------------------------------------------------------

(define-prim&proc (expand-quote stx cte)
  stx)

(define-prim&proc (expand-quote-syntax stx cte)
  stx)

(define-prim&proc (expand-syntax stx cte)
  stx)

(define-prim&proc (expand-unquote s cte)
  (##raise-expression-parsing-exception
    'ill-placed-unquote
    s))

(define-prim&proc (expand-unquote-splicing s cte)
  (##raise-expression-parsing-exception
    'ill-placed-unqote-splicing
    s))

(define-primitive (implicit-prefix-apply sym stx-src)
  (##plain-datum->syntax
    `(,(##make-core-syntax-source sym #f) ,stx-src)
     stx-src))

(define-prim&proc (expand-quasiquote s cte)

  (define (tag-quasiquote? code)
    (and (##pair? code)
         (##member (##syntax-source-code (##car code)) (##list 'quasiquote '##quasiquote))
         (##pair? (##cdr code))
         (##cadr code)))

  (define (tag-unquote? code)
    (and (##pair? code)
         (##member (##syntax-source-code (##car code)) (##list 'unquote '##unquote))
         (##pair? (##cdr code))
         (##cadr code)))

  (define (tag-unquote-splicing? code)
    (and (##pair? code)
         (##member (##syntax-source-code (##car code)) (##list 'unquote-splicing '##unquote-splicing))
         (##pair? (##cdr code))
         (##cadr code)))

  (define (expand-template s)

    (let ((code (##syntax-source-code s)))
      (cond
        ((tag-unquote? code)
          => (lambda (datum) (##expand datum cte)))
        ((tag-unquote-splicing? code) 
         (error "Invalid use of unquote-splicing"))
        #;((tag-quasiquote? code)
           => (lambda (datum)
                (expand-template
                  (expand-template (##syntax-source-code-set s datum)))))
        ((and (##pair? code) (not (tag-quasiquote? code)))
         (##syntax-source-code-set s
           `(,(##make-core-syntax-source '##append #f)
                ,(expand-template-list (##car code))
                ,(expand-template (let ((rest (cdr code)))
                                    (if (or (pair? rest) (null? rest))
                                        (##syntax-source-code-set s rest)
                                        rest))))))
        (else
          (##implicit-prefix-apply '##quote s)))))
        
  (define (expand-template-list s)
    (let ((code (##syntax-source-code s)))
      (cond 
        ((tag-unquote? code)
         => (lambda (datum)
              (##syntax-source-code-set s 
                (##list 
                  (##make-core-syntax-source '##list #f)
                  (##expand datum cte)))))
        ((tag-unquote-splicing? code)
         => (lambda (datum) (##expand datum cte)))
        ((and (##pair? code) (not (tag-quasiquote? code)))
         (##implicit-prefix-apply '##list
           (syntax-source-code-set s
               `(,(##make-core-syntax-source '##append #f)
                  ,(expand-template-list (##car code))
                  ,(expand-template      (let ((rest (cdr code)))
                                           (if (or (pair? rest) (null? rest))
                                               (##syntax-source-code-set s rest)
                                               rest)))))))
        (else
          (##plain-datum->syntax 
            `(,(##make-core-syntax-source '##quote #f)
              ,(##syntax-source-code-set s (##list s)))
            s)))))

  (let* ((code (##syntax-source-code s)))
    (if (and (##pair? code) 
             (##pair? (##cdr code)) 
             (##null? (##cddr code)))
        (let ((datum (##cadr code)))
          (expand-template datum))
        (##error "quasiquote error"))))

;;;----------------------------------------------------------------------------

(define-prim&proc (expand-namespace stx cte)
  (top-hcte-process-namespace! cte stx)
  stx
  #;(match-source stx ()
    ((namespace-id (prefix . aliases))
     (top-hcte-process-namespace! cte stx)
     stx)
    (_
     (error "ill formed namespace form"))))

(define-prim&proc (expand-include stx-src cte)

  (define (##include-file-as-a-begin-expr src)

    (define (include-file fn-src ci?)
      (let* ((filename-src (##sourcify fn-src src))
             (filename (##source-code filename-src)))
        (if (##string? filename)

            (let* ((relative-to-path
                    (##source-path src))
                   (path
                    (##path-reference filename relative-to-path))
                   (x
                    (##read-all-as-a-begin-expr-from-path
                     path
                     (##current-readtable)
                     ##wrap-datum
                     ##unwrap-datum
                     (if ci? #t '()))))
              (if (##fixnum? x)
                  (##raise-expression-parsing-exception
                   'cannot-open-file
                   src
                   path)
                  (##vector-ref x 1)))

            (##raise-expression-parsing-exception
             'filename-expected
             filename-src))))

    (let* ((code (##source-code src))
           (ci? (##eq? (##source-code (##sourcify (##car code) src))
                       '##include-ci))
           (lst (##map (lambda (fn-src) (include-file fn-src ci?))
                       (##cdr code))))
      (if (and (##pair? lst) (##null? (##cdr lst)))
          (##car lst)
          (##make-source
           (##cons '##begin lst)
           src))))

  (let ((file-src (##include-file-as-a-begin-expr stx-src)))
    (let ((file-stx (add-scope (##datum->syntax file-src (car (##source-code stx-src))) core-scope)))
      (##expand file-stx cte))))

;;;----------------------------------------------------------------------------

(define-prim&proc (expand-case stx cte)

  (define (expand-clauses clauses cte)
    (cond
      ((pair? clauses)
       (let ((clause (car clauses))
             (clauses (cdr clauses)))
         (cons
           (match-source clause ()
             ((id val)
              (syntax-source-code-set clause
                `(,id ,(expand val cte)))))
           (expand-clauses clauses cte))))
      ((null? clauses)
       clauses)
      (else
        (error "ill-formed case clause"))))

  (match-source stx ()
    ((case-id expr . clauses)
     (let ((expr (expand expr cte))
           (clauses (expand-clauses clauses cte)))
       (syntax-source-code-set stx
         `(,case-id ,expr ,@clauses))))))
  
(define (##expand-cond stx-src cte)

  (define (##expand-cond-clause clause next-clause cte)
    (match-source clause ()
      ((condition => expr) when (##equal? (##syntax-source-code =>) 
                                        '=>)
       (##plain-datum->core-syntax
         `(let ((x ,(##expand condition cte)))
            (if x
                (,(##expand expr cte) x)
                ,next-clause))
          clause))
      ((condition . exprs)
       (##plain-datum->core-syntax
        (let ((expanded-condition (##expand condition cte)))
         `(if ,expanded-condition
              ,(if (pair? exprs)
                   (##expand (##syntax-source-code-set stx-src 
                               (##cons (##make-core-syntax-source '##begin #f)
                                   exprs))
                             cte)
                   expanded-condition)
              ,next-clause))))
      (else
        (##pretty-print clause)
       (##error "cond: ill formed clause"))))

  (match-source stx-src ()
    ((cond-id . clauses)

     (let* ((r-clauses (##reverse clauses))
            (last-clause (##car r-clauses)))
       (let ((else-clause? 
               (and (##equal? 'else
                            (##syntax-source-code 
                              (car (##syntax-source-code last-clause))))
                    (##expand (##cadr (##syntax-source-code last-clause)) cte))))
         (let ((r-clauses (##reverse (if else-clause?
                              (##cdr r-clauses)
                              r-clauses))))
             (let loop ((clauses r-clauses))
               (cond 
                 ((##pair? clauses)
                  (let ((clause (##car clauses)))
                    (##expand-cond-clause clause 
                                          (loop (##cdr clauses))
                                          cte)))
                 ((##null? clauses)
                  (if else-clause?
                      else-clause?
                      #f #;`(##error "cond : no match")))))))))
    (_
      (##pretty-print stx-src)
      (error "ill formed cond form"))))

;;;----------------------------------------------------------------------------

(define-prim&proc (expand stx cte)
  (let ((code (syntax-source-code stx)))
    (cond
      ((null? code)
       stx)
      ((pair? code)
       (cond
         ((identifier? (car code))
          (##expand-id-application-form (car code) stx cte))
         (else
          (##expand-pair stx cte))))
      ((identifier? stx)
       (##expand-identifier stx cte))
      ((keyword? (syntax-source-code stx))
       stx
       #;(##expand-keyword-argument stx cte))
      ((boolean? (syntax-source-code stx))
       stx)
      ((string? code)
       stx)
      (else
       (syntax-source-code-set stx
         `(,(##make-core-syntax-source '##quote #f) ,stx))))))

;;;============================================================================