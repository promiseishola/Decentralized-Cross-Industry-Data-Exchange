;; Usage Tracking Contract
;; Monitors consumption of shared data

;; Traits
(define-trait access-control-trait
  (
    (has-access (uint principal) (response bool uint))
  )
)


;; Data Maps
(define-map usage-records uint {
  asset-id: uint,
  user: principal,
  timestamp: uint,
  access-type: (string-utf8 20),
  metadata: (string-utf8 256)
})

(define-map asset-usage-count uint uint)
(define-map user-usage-count principal uint)

;; Variables
(define-data-var usage-counter uint u0)

;; Error Codes
(define-constant ERR-NOT-AUTHORIZED u400)
(define-constant ERR-NO-ACCESS u401)

;; Read-only functions
(define-read-only (get-usage-record (usage-id uint))
  (map-get? usage-records usage-id)
)

(define-read-only (get-asset-usage (asset-id uint))
  (default-to u0 (map-get? asset-usage-count asset-id))
)

(define-read-only (get-user-usage (user principal))
  (default-to u0 (map-get? user-usage-count user))
)

(define-read-only (get-usage-count)
  (var-get usage-counter)
)

;; Public functions
(define-public (record-usage
    (access-control-contract <access-control-trait>)
    (asset-id uint)
    (access-type (string-utf8 20))
    (metadata (string-utf8 256)))
  (let (
    (caller tx-sender)
    (usage-id (+ (var-get usage-counter) u1))
    (current-asset-usage (default-to u0 (map-get? asset-usage-count asset-id)))
    (current-user-usage (default-to u0 (map-get? user-usage-count caller)))
  )
    ;; Check if user has access to the asset
    (asserts! (unwrap! (contract-call? access-control-contract has-access asset-id caller) (err ERR-NO-ACCESS))
              (err ERR-NO-ACCESS))

    ;; Record usage
    (map-set usage-records usage-id {
      asset-id: asset-id,
      user: caller,
      timestamp: block-height,
      access-type: access-type,
      metadata: metadata
    })

    ;; Update counters
    (map-set asset-usage-count asset-id (+ current-asset-usage u1))
    (map-set user-usage-count caller (+ current-user-usage u1))
    (var-set usage-counter usage-id)

    (ok usage-id)
  )
)
