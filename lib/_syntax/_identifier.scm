;;;============================================================================

;;; File: "_identifier.scm"

;;; Copyright (c) 2024 by Antoine Doucet, All Rights Reserved.
;;; Copyright (c) 2024 by Marc Feeley, All Rights Reserved.

;;;============================================================================

(define-prim&proc (identifier? obj)
  (and (syntax-source? obj)
       (symbol? (syntax-source-code obj))
       obj))

(define (##fail-check-identifier arg-id proc . args)
  (##raise-type-exception
   arg-id
   #!void 
   proc
   args))

(define-check-type identifier (type-scope)
  identifier?)

(define-prim&proc (identifier-copy (id identifier))
  (##vector-copy id))

(define (identifier-equal? id1 id2)
  (and (identifier? id1)
       (identifier? id2)
       (scopes-equal? (syntax-source-scopes id1)
                      (syntax-source-scopes id2))))


(define (free-identitifer? id1 id2)
  ; TODO copy back
  #t
)

(define (bound-identifier? id1 id2)
  ; TODO copy back
  #f)

;;;============================================================================