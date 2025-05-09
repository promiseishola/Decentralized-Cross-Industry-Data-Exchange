;; Access Control Contract
;; Manages permissions for data sharing

;; Data Maps
(define-map access-grants
  { asset-id: uint, grantee: principal }
  { grantor: principal, granted-at: uint, expires-at: uint, revoked: bool }
)

(define-map asset-grantees uint (list 100 principal))

;; Error Codes
(define-constant ERR-NOT-AUTHORIZED u300)
(define-constant ERR-ASSET-NOT-FOUND u301)
(define-constant ERR-NOT-VERIFIED-ENTITY u302)
(define-constant ERR-GRANT-NOT-FOUND u303)
(define-constant ERR-GRANT-EXPIRED u304)
(define-constant ERR-GRANT-REVOKED u305)

;; Read-only functions
(define-read-only (has-access (asset-id uint) (grantee principal))
  (let (
    (grant (map-get? access-grants { asset-id: asset-id, grantee: grantee }))
  )
    (and
      (is-some grant)
      (not (get revoked (unwrap! grant false)))
      (< block-height (get expires-at (unwrap! grant false)))
    )
  )
)

(define-read-only (get-access-details (asset-id uint) (grantee principal))
  (map-get? access-grants { asset-id: asset-id, grantee: grantee })
)

(define-read-only (get-asset-grantees (asset-id uint))
  (default-to (list) (map-get? asset-grantees asset-id))
)

;; Public functions
(define-public (grant-access
    (entity-verification-contract principal)
    (data-asset-contract principal)
    (asset-id uint)
    (grantee principal)
    (expires-at uint))
  (let (
    (caller tx-sender)
    (asset (unwrap! (contract-call? data-asset-contract get-asset asset-id) (err ERR-ASSET-NOT-FOUND)))
    (current-grantees (default-to (list) (map-get? asset-grantees asset-id)))
  )
    ;; Check if caller is the asset owner
    (asserts! (is-eq (get owner asset) caller) (err ERR-NOT-AUTHORIZED))

    ;; Check if grantee is a verified entity
    (asserts! (contract-call? entity-verification-contract is-verified grantee)
              (err ERR-NOT-VERIFIED-ENTITY))

    ;; Grant access
    (map-set access-grants
      { asset-id: asset-id, grantee: grantee }
      { grantor: caller, granted-at: block-height, expires-at: expires-at, revoked: false }
    )

    ;; Update asset grantees list if not already in the list
    (if (index-of current-grantees grantee)
      (ok true)
      (begin
        (map-set asset-grantees asset-id (append current-grantees grantee))
        (ok true)
      )
    )
  )
)

(define-public (revoke-access (asset-id uint) (grantee principal))
  (let (
    (caller tx-sender)
    (grant (unwrap! (map-get? access-grants { asset-id: asset-id, grantee: grantee }) (err ERR-GRANT-NOT-FOUND)))
  )
    ;; Check if caller is the grantor
    (asserts! (is-eq (get grantor grant) caller) (err ERR-NOT-AUTHORIZED))

    ;; Revoke access
    (map-set access-grants
      { asset-id: asset-id, grantee: grantee }
      (merge grant { revoked: true })
    )

    (ok true)
  )
)
