# hygienic macro system implementation

## Dev Integration check-list:

- Integrate interpretation envrionment
  - integrate new "locat" container.
    In the last Gambit's version, source vector
    were modified to accept an extra location parameter,
    making source object a contianer of variable size.
    This clash with the new source vector representation.
  - Use the "descriptor" structure instead of plain procedure for
    macro definition's expansion. Those are usefull to reconstruct the expander
    definitions and show the expected form to the user (for forms such as `cond`).
    This is the last difference between the `##interaction-cte` and the `##syntax-interaction-cte`.
    This can be done once the new `define-macro` form performs well enough to replace the old one.
    (or we decide to keep the old `define-macro` as both forms are unhygienic by definition. Unsure yet
    if breaking hygiene with the new system (as with the new `define-macro`) 
    is required to keep the hygiene system sane)
    We can then completely merge the `##interaction-cte` and the `##syntax-interaction-cte`.

- Integrate compilation environment
  - Interface for hygienic compile cte is implemented 
    in my own fork, waiting only to be merged once
    performances are satisfaying.

- Performance
  - (In progress)
    Investigate the non-linear comportment of
    `define-macro`. The problem might be arising from
    a poor handling of top-level macro definitions in local
    context. This could be due to a "deeper" problem,
    however. 

- Correctness
  - serialise compilation environements.
  - Fix `define-library` by removing references to the old syntax system.
    - Some modules (from `make modules`) were not tested for correctness yet.
  - use `free-identitifer?` for literals in `syntax-case`.
    - this was ommited when refactoring syntax-case.
  - Fix `make checks` as the string comparaison doesn't work anymore 
    with hygienically renamed identifiers.
  - rename `plain-datum->syntax` as `datum->syntax`
    rename `datum->syntax` as `source->syntax`.
  - Bugs:
    - unknown bug with `full-name?`

## Full Integration check-list:

- Syntax
  - Completely remove every references to the old macro system.
  - Investigate the strategies used to accelerate the compilation
    of those old syntax construct and make sure we do the same when we can.
  - Complete hygiene would rejects programs with undeclared identifiers. 
    Must fill up the environment.

- GSI
  - merge the original `compile-top` "phase" with 
    the hygienic "compile" phase. Make sure the stepper doesn't
    interfere with the hygiene algorithm.

- GSC
  - merge the compilation phase to the hygienic compile phase.
    (Almost achievable for "free")
