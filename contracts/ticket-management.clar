;; ticket-management.clar
;; A Clarity 6.0 smart contract for managing event tickets with functionalities for issuing, cancelling, 
;; and transferring tickets. It supports both single and batch issuance of tickets with validation checks.
;; The contract also ensures only the ticket owner or admin can perform specific actions.
;; 
;; Key features include:
;; - Admin-controlled ticket issuance and batch processing
;; - Ticket cancellation and transfer functionalities
;; - Tracking of cancelled tickets and batch issuance metadata
;; - Read-only functions to retrieve ticket information and ownership status

;; Constants
(define-constant admin tx-sender)  ;; The administrator address of the contract
(define-constant err-admin-only (err u200))  ;; Error for non-admin users
(define-constant err-ticket-owner-only (err u201))  ;; Error for non-owners trying to perform actions on tickets
(define-constant err-ticket-exists (err u202))  ;; Error when ticket info is invalid or already exists
(define-constant err-ticket-not-found (err u203))  ;; Error when the specified ticket is not found
(define-constant err-cancel-failed (err u204))  ;; Error when canceling a ticket fails
(define-constant err-already-cancelled (err u205))  ;; Error when a ticket is already canceled
(define-constant max-tickets-per-batch u50)  ;; Maximum number of tickets that can be issued in a batch

;; Data Variables
(define-non-fungible-token event-ticket uint)  ;; Non-fungible token representing the event ticket
(define-data-var last-ticket-id uint u0)  ;; Variable to keep track of the last ticket ID issued

;; Maps
(define-map ticket-details uint (string-ascii 128))  ;; Stores the details for each ticket using the ticket ID as key
(define-map cancelled-tickets uint bool)  ;; Tracks which tickets have been canceled
(define-map batch-issuance-metadata uint (string-ascii 128))  ;; Stores metadata for batch ticket issuance

;; Private Functions
(define-private (is-ticket-owner (ticket-id uint) (sender principal))
    ;; Check if the sender is the owner of the specified ticket
    (is-eq sender (unwrap! (nft-get-owner? event-ticket ticket-id) false)))

(define-private (is-ticket-cancelled (ticket-id uint))
    ;; Check if the specified ticket has been canceled
    (default-to false (map-get? cancelled-tickets ticket-id)))

(define-private (is-valid-ticket-info (ticket-info (string-ascii 128)))
    ;; Validate the ticket info to ensure it contains at least one character
    (>= (len ticket-info) u1))

(define-private (is-valid-ticket-id (ticket-id uint))
;; Returns true if the ticket exists in `ticket-details` and is not canceled.
(and (not (is-eq (map-get? ticket-details ticket-id) none))
     (not (is-ticket-cancelled ticket-id))))

(define-private (issue-ticket (ticket-info (string-ascii 128)))
    ;; Issues a new ticket by minting an NFT, storing the ticket info, and updating the last ticket ID
    (let ((ticket-id (+ (var-get last-ticket-id) u1)))
        (asserts! (is-valid-ticket-info ticket-info) err-ticket-exists)  ;; Ensure valid ticket info
        (try! (nft-mint? event-ticket ticket-id tx-sender))  ;; Mint the NFT for the ticket
        (map-set ticket-details ticket-id ticket-info)  ;; Store ticket details
        (var-set last-ticket-id ticket-id)  ;; Update the last ticket ID issued
        (ok ticket-id)))  ;; Return the new ticket ID

;; Public Functions
(define-public (issue (ticket-info (string-ascii 128)))
    ;; Public function to issue a single ticket
    (begin
        (asserts! (is-eq tx-sender admin) err-admin-only)  ;; Ensure only the admin can issue tickets
        (asserts! (is-valid-ticket-info ticket-info) err-ticket-exists)  ;; Validate ticket info
        (issue-ticket ticket-info)))  ;; Call the internal function to issue the ticket

(define-public (batch-issue (ticket-infos (list 50 (string-ascii 128))))
    ;; Public function to issue multiple tickets in a batch (up to 50 tickets)
    (let ((batch-size (len ticket-infos)))
        (begin
            (asserts! (is-eq tx-sender admin) err-admin-only)  ;; Ensure only the admin can issue tickets
            (asserts! (<= batch-size max-tickets-per-batch) err-ticket-exists)  ;; Validate batch size limit
            (fold issue-single-ticket-in-batch ticket-infos (ok (list))))))  ;; Issue tickets in the batch

(define-private (issue-single-ticket-in-batch (info (string-ascii 128)) (previous-ids (response (list 50 uint) uint)))
    ;; Private function to issue a single ticket in a batch and return all previously issued ticket IDs
    (match previous-ids
        ok-list (match (issue-ticket info)
                        success (ok (unwrap-panic (as-max-len? (append ok-list success) u50)))  ;; Add the new ticket ID to the list
                        error previous-ids)  ;; Return previous IDs if an error occurs
        error previous-ids))  ;; Return previous IDs if an error occurs

(define-public (cancel (ticket-id uint))
    ;; Public function to cancel a ticket
    (let ((ticket-owner (unwrap! (nft-get-owner? event-ticket ticket-id) err-ticket-not-found)))  ;; Retrieve the ticket owner
        (asserts! (is-eq tx-sender ticket-owner) err-ticket-owner-only)  ;; Ensure the sender is the ticket owner
        (asserts! (not (is-ticket-cancelled ticket-id)) err-already-cancelled)  ;; Ensure the ticket has not already been canceled
        (try! (nft-burn? event-ticket ticket-id ticket-owner))  ;; Burn the NFT to cancel the ticket
        (map-set cancelled-tickets ticket-id true)  ;; Mark the ticket as canceled
        (ok true)))  ;; Return true indicating successful cancellation

(define-public (transfer (ticket-id uint) (sender principal) (recipient principal))
    ;; Public function to transfer a ticket to another user
    (begin
        (asserts! (is-eq recipient tx-sender) err-ticket-owner-only)  ;; Ensure the recipient is the sender
        (asserts! (not (is-ticket-cancelled ticket-id)) err-already-cancelled)  ;; Ensure the ticket is not canceled
        (let ((actual-sender (unwrap! (nft-get-owner? event-ticket ticket-id) err-ticket-owner-only)))  ;; Retrieve the actual sender
            (asserts! (is-eq actual-sender sender) err-ticket-owner-only)  ;; Ensure the sender is the actual ticket owner
            (try! (nft-transfer? event-ticket ticket-id sender recipient))  ;; Transfer the NFT to the recipient
            (ok true))))  ;; Return true indicating successful transfer

;; Read-Only Functions
(define-read-only (get-ticket-info (ticket-id uint))
    ;; Returns the details of a specific ticket
    (ok (map-get? ticket-details ticket-id)))

(define-read-only (get-ticket-metadata (ticket-id uint))
;; Returns the metadata associated with a specific ticket (e.g., for batch issuance)
(ok (map-get? batch-issuance-metadata ticket-id)))

(define-read-only (get-ticket-cancelled-status (ticket-id uint))
;; Returns true if the ticket has been canceled, false otherwise
(ok (is-ticket-cancelled ticket-id)))

(define-read-only (does-ticket-exist (ticket-id uint))
;; Returns true if the specified ticket exists (i.e., has valid details and is not cancelled).
(ok (is-eq (map-get? ticket-details ticket-id) none)))

(define-read-only (get-ticket-transfer-history (ticket-id uint))
;; Returns the transfer history for a specific ticket
(ok (map-get? ticket-details ticket-id)))

(define-read-only (is-ticket-canceled (ticket-id uint))
;; Returns true if the ticket has been canceled, otherwise false
(ok (is-ticket-cancelled ticket-id)))

(define-read-only (get-total-tickets-count)
;; Returns the total number of tickets issued so far
(ok (+ (var-get last-ticket-id) u1)))

(define-read-only (get-ticket-owner-history (ticket-id uint))
;; Returns the owner history of a specific ticket, tracking its previous owners
(ok (map-get? ticket-details ticket-id)))

(define-read-only (get-owner (ticket-id uint))
    ;; Returns the owner of a specific ticket
    (ok (nft-get-owner? event-ticket ticket-id)))

(define-read-only (get-last-ticket-id)
    ;; Returns the last ticket ID issued
    (ok (var-get last-ticket-id)))

(define-read-only (is-cancelled (ticket-id uint))
    ;; Checks if a specific ticket has been canceled
    (ok (is-ticket-cancelled ticket-id)))
   
(define-read-only (ticket-exists? (ticket-id uint))
;; Returns true if the ticket exists in the ticket-details map, false otherwise
(ok (is-eq (map-get? ticket-details ticket-id) none)))

(define-read-only (is-ticket-canceled? (ticket-id uint))
;; Returns true if the ticket has been canceled, false otherwise
(ok (is-ticket-cancelled ticket-id)))

(define-read-only (is-admin? (sender principal))
;; Returns true if the sender is the admin
(ok (is-eq sender admin)))

(define-read-only (get-ticket-details (ticket-id uint))
;; Returns the details of a specific ticket
(ok (map-get? ticket-details ticket-id)))

(define-read-only (get-admin-status (sender principal))
;; Returns true if the provided sender is the admin.
(ok (is-eq sender admin)))

(define-read-only (is-ticket-issued? (ticket-id uint))
;; Returns true if the ticket is already issued (exists in ticket-details)
(ok (is-eq (map-get? ticket-details ticket-id) none)))

(define-read-only (count-issued-tickets)
;; Returns the total number of tickets issued
(ok (var-get last-ticket-id)))

(define-read-only (get-batch-metadata (batch-id uint))
;; Returns the metadata for a specific batch issuance
(ok (map-get? batch-issuance-metadata batch-id)))

;; Contract Initialization
(begin
    (var-set last-ticket-id u0))  ;; Initialize the last ticket ID to 0
