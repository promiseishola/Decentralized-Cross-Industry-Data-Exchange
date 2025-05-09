;; Entity Verification Contract
;; Validates participating organizations in the data exchange network

;; Data Maps
(define-map verified-entities principal bool)
(define-map entity-details principal {name: (string-utf8 100), industry: (string-utf8 50), verified-at: uint})

;; Error Codes
(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-ALREADY-VERIFIED u101)
(define-constant ERR-NOT-VERIFIED u102)

;; Governance
(define-data-var contract-owner principal tx-sender)

;; Read-only functions
(define-read-only (is-verified (entity principal))
  (default-to false (map-get? verified-entities entity))
)

(define-read-only (get-entity-details (entity principal))
  (map-get? entity-details entity)
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

;; Public functions
(define-public (register-entity (name (string-utf8 100)) (industry (string-utf8 50)))
  (let ((caller tx-sender))
    (asserts! (not (is-verified caller)) (err ERR-ALREADY-VERIFIED))

    (map-set verified-entities caller true)
    (map-set entity-details caller {
      name: name,
      industry: industry,
      verified-at: block-height
    })

    (ok true)
  )
)

(define-public (revoke-entity (entity principal))
  (begin
    (asserts! (is-contract-owner) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-verified entity) (err ERR-NOT-VERIFIED))

    (map-delete verified-entities entity)
    (map-delete entity-details entity)

    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) (err ERR-NOT-AUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Private functions
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)
