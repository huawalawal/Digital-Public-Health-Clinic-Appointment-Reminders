# Digital Public Health Clinic Appointment Reminders

A comprehensive blockchain-based appointment management system for public health clinics, built on the Stacks blockchain using Clarity smart contracts.

## System Overview

This system manages the complete appointment lifecycle for public health clinics through five interconnected smart contracts:

### Core Contracts

1. **Reminder Scheduling Contract** (`reminder-scheduling.clar`)
    - Schedules and sends appointment confirmations via phone and text
    - Manages reminder timing and delivery methods
    - Tracks confirmation status

2. **Cancellation Processing Contract** (`cancellation-processing.clar`)
    - Handles patient appointment changes and cancellations
    - Processes refunds and rescheduling requests
    - Maintains cancellation history

3. **No-Show Tracking Contract** (`no-show-tracking.clar`)
    - Records missed appointments and patient no-shows
    - Implements penalty systems for repeated no-shows
    - Manages automatic rescheduling

4. **Wait List Management Contract** (`wait-list-management.clar`)
    - Maintains patient wait lists for popular time slots
    - Automatically fills cancelled appointments with waiting patients
    - Prioritizes patients based on urgency and wait time

5. **Insurance Verification Contract** (`insurance-verification.clar`)
    - Confirms insurance coverage before appointment dates
    - Validates patient eligibility
    - Tracks verification status and expiration dates

## Features

- **Automated Reminders**: Phone and text message confirmations
- **Real-time Cancellation Processing**: Immediate slot availability updates
- **No-show Prevention**: Tracking and penalty systems
- **Efficient Wait List Management**: Automatic patient matching
- **Insurance Validation**: Pre-appointment coverage verification
- **Audit Trail**: Complete appointment lifecycle tracking

## Data Structures

### Appointment
- `appointment-id`: Unique identifier
- `patient-id`: Patient identifier
- `clinic-id`: Clinic identifier
- `appointment-date`: Scheduled date and time
- `status`: Current appointment status
- `reminder-sent`: Confirmation tracking
- `insurance-verified`: Coverage status

### Patient
- `patient-id`: Unique identifier
- `phone`: Contact phone number
- `insurance-id`: Insurance information
- `no-show-count`: Missed appointment counter
- `priority-level`: Wait list priority

## Installation

1. Install Clarinet CLI
2. Clone this repository
3. Run `clarinet check` to validate contracts
4. Run `npm test` to execute test suite

## Testing

The system includes comprehensive tests using Vitest:

\`\`\`bash
npm install
npm test
\`\`\`

## Usage

Deploy contracts to Stacks blockchain and interact through the provided functions:

- Schedule appointments and reminders
- Process cancellations and changes
- Track no-shows and manage penalties
- Manage wait lists and automatic filling
- Verify insurance coverage

## Security Features

- Input validation on all contract functions
- Access control for administrative functions
- Immutable appointment history
- Secure patient data handling

## Contract Interactions

Contracts are designed to work independently while maintaining data consistency across the system. Each contract handles its specific domain while providing interfaces for cross-contract coordination.
\`\`\`

```clar file="contracts/reminder-scheduling.clar"
;; Reminder Scheduling Contract
;; Manages appointment confirmations via phone and text

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-APPOINTMENT-NOT-FOUND (err u101))
(define-constant ERR-INVALID-INPUT (err u102))
(define-constant ERR-REMINDER-ALREADY-SENT (err u103))

;; Data Variables
(define-data-var next-reminder-id uint u1)

;; Data Maps
(define-map appointments
  { appointment-id: uint }
  {
    patient-id: uint,
    clinic-id: uint,
    appointment-date: uint,
    phone: (string-ascii 15),
    reminder-sent: bool,
    confirmation-method: (string-ascii 10),
    created-at: uint
  }
)

(define-map reminders
  { reminder-id: uint }
  {
    appointment-id: uint,
    reminder-type: (string-ascii 10),
    scheduled-time: uint,
    sent: bool,
    delivery-status: (string-ascii 20)
  }
)

;; Public Functions

;; Schedule a new appointment with reminder
(define-public (schedule-appointment 
  (appointment-id uint)
  (patient-id uint)
  (clinic-id uint)
  (appointment-date uint)
  (phone (string-ascii 15))
  (confirmation-method (string-ascii 10)))
  (begin
    (asserts! (> appointment-id u0) ERR-INVALID-INPUT)
    (asserts! (> patient-id u0) ERR-INVALID-INPUT)
    (asserts! (> clinic-id u0) ERR-INVALID-INPUT)
    (asserts! (> appointment-date block-height) ERR-INVALID-INPUT)
    
    (map-set appointments
      { appointment-id: appointment-id }
      {
        patient-id: patient-id,
        clinic-id: clinic-id,
        appointment-date: appointment-date,
        phone: phone,
        reminder-sent: false,
        confirmation-method: confirmation-method,
        created-at: block-height
      }
    )
    (ok appointment-id)
  )
)

;; Send appointment reminder
(define-public (send-reminder (appointment-id uint) (reminder-type (string-ascii 10)))
  (let ((appointment (unwrap! (map-get? appointments { appointment-id: appointment-id }) ERR-APPOINTMENT-NOT-FOUND))
        (reminder-id (var-get next-reminder-id)))
    
    (asserts! (not (get reminder-sent appointment)) ERR-REMINDER-ALREADY-SENT)
    
    ;; Create reminder record
    (map-set reminders
      { reminder-id: reminder-id }
      {
        appointment-id: appointment-id,
        reminder-type: reminder-type,
        scheduled-time: block-height,
        sent: true,
        delivery-status: "sent"
      }
    )
    
    ;; Update appointment reminder status
    (map-set appointments
      { appointment-id: appointment-id }
      (merge appointment { reminder-sent: true })
    )
    
    ;; Increment reminder ID
    (var-set next-reminder-id (+ reminder-id u1))
    (ok reminder-id)
  )
)

;; Update reminder delivery status
(define-public (update-delivery-status (reminder-id uint) (status (string-ascii 20)))
  (let ((reminder (unwrap! (map-get? reminders { reminder-id: reminder-id }) ERR-APPOINTMENT-NOT-FOUND)))
    (map-set reminders
      { reminder-id: reminder-id }
      (merge reminder { delivery-status: status })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get appointment details
(define-read-only (get-appointment (appointment-id uint))
  (map-get? appointments { appointment-id: appointment-id })
)

;; Get reminder details
(define-read-only (get-reminder (reminder-id uint))
  (map-get? reminders { reminder-id: reminder-id })
)

;; Check if reminder was sent
(define-read-only (is-reminder-sent (appointment-id uint))
  (match (map-get? appointments { appointment-id: appointment-id })
    appointment (get reminder-sent appointment)
    false
  )
)

;; Get next reminder ID
(define-read-only (get-next-reminder-id)
  (var-get next-reminder-id)
)
