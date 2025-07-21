;; Cancellation Processing Contract
;; Handles patient appointment changes and cancellations

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-APPOINTMENT-NOT-FOUND (err u201))
(define-constant ERR-INVALID-INPUT (err u202))
(define-constant ERR-ALREADY-CANCELLED (err u203))
(define-constant ERR-TOO-LATE-TO-CANCEL (err u204))

;; Data Variables
(define-data-var next-cancellation-id uint u1)
(define-data-var cancellation-deadline-hours uint u24)

;; Data Maps
(define-map appointment-status
  { appointment-id: uint }
  {
    status: (string-ascii 20),
    patient-id: uint,
    appointment-date: uint,
    cancellation-reason: (optional (string-ascii 100)),
    cancelled-at: (optional uint),
    refund-amount: uint
  }
)

(define-map cancellations
  { cancellation-id: uint }
  {
    appointment-id: uint,
    patient-id: uint,
    cancellation-type: (string-ascii 20),
    reason: (string-ascii 100),
    refund-processed: bool,
    cancelled-at: uint
  }
)

(define-map reschedule-requests
  { appointment-id: uint }
  {
    original-date: uint,
    requested-date: uint,
    approved: bool,
    processed-at: uint
  }
)

;; Public Functions

;; Register an appointment for cancellation tracking
(define-public (register-appointment
  (appointment-id uint)
  (patient-id uint)
  (appointment-date uint))
  (begin
    (asserts! (> appointment-id u0) ERR-INVALID-INPUT)
    (asserts! (> patient-id u0) ERR-INVALID-INPUT)
    (asserts! (> appointment-date block-height) ERR-INVALID-INPUT)

    (map-set appointment-status
      { appointment-id: appointment-id }
      {
        status: "scheduled",
        patient-id: patient-id,
        appointment-date: appointment-date,
        cancellation-reason: none,
        cancelled-at: none,
        refund-amount: u0
      }
    )
    (ok appointment-id)
  )
)

;; Cancel an appointment
(define-public (cancel-appointment
  (appointment-id uint)
  (reason (string-ascii 100))
  (refund-amount uint))
  (let ((appointment (unwrap! (map-get? appointment-status { appointment-id: appointment-id }) ERR-APPOINTMENT-NOT-FOUND))
        (cancellation-id (var-get next-cancellation-id))
        (deadline-blocks (* (var-get cancellation-deadline-hours) u6))) ;; Assuming 6 blocks per hour

    (asserts! (is-eq (get status appointment) "scheduled") ERR-ALREADY-CANCELLED)
    (asserts! (>= (- (get appointment-date appointment) block-height) deadline-blocks) ERR-TOO-LATE-TO-CANCEL)

    ;; Update appointment status
    (map-set appointment-status
      { appointment-id: appointment-id }
      (merge appointment {
        status: "cancelled",
        cancellation-reason: (some reason),
        cancelled-at: (some block-height),
        refund-amount: refund-amount
      })
    )

    ;; Create cancellation record
    (map-set cancellations
      { cancellation-id: cancellation-id }
      {
        appointment-id: appointment-id,
        patient-id: (get patient-id appointment),
        cancellation-type: "patient-initiated",
        reason: reason,
        refund-processed: false,
        cancelled-at: block-height
      }
    )

    (var-set next-cancellation-id (+ cancellation-id u1))
    (ok cancellation-id)
  )
)

;; Request appointment reschedule
(define-public (request-reschedule
  (appointment-id uint)
  (new-date uint))
  (let ((appointment (unwrap! (map-get? appointment-status { appointment-id: appointment-id }) ERR-APPOINTMENT-NOT-FOUND)))

    (asserts! (is-eq (get status appointment) "scheduled") ERR-ALREADY-CANCELLED)
    (asserts! (> new-date block-height) ERR-INVALID-INPUT)

    (map-set reschedule-requests
      { appointment-id: appointment-id }
      {
        original-date: (get appointment-date appointment),
        requested-date: new-date,
        approved: false,
        processed-at: block-height
      }
    )
    (ok true)
  )
)

;; Process refund
(define-public (process-refund (cancellation-id uint))
  (let ((cancellation (unwrap! (map-get? cancellations { cancellation-id: cancellation-id }) ERR-APPOINTMENT-NOT-FOUND)))

    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (not (get refund-processed cancellation)) ERR-INVALID-INPUT)

    (map-set cancellations
      { cancellation-id: cancellation-id }
      (merge cancellation { refund-processed: true })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get appointment status
(define-read-only (get-appointment-status (appointment-id uint))
  (map-get? appointment-status { appointment-id: appointment-id })
)

;; Get cancellation details
(define-read-only (get-cancellation (cancellation-id uint))
  (map-get? cancellations { cancellation-id: cancellation-id })
)

;; Get reschedule request
(define-read-only (get-reschedule-request (appointment-id uint))
  (map-get? reschedule-requests { appointment-id: appointment-id })
)

;; Check if appointment is cancelled
(define-read-only (is-cancelled (appointment-id uint))
  (match (map-get? appointment-status { appointment-id: appointment-id })
    appointment (is-eq (get status appointment) "cancelled")
    false
  )
)
