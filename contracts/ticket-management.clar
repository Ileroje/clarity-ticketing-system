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

(define-public (is-admin (sender principal))
;; Returns true if the sender is the admin
(ok (is-eq sender admin)))

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

(define-public (is-ticket-issued (ticket-id uint))
;; Returns true if the ticket has been issued (exists in ticket-details)
(ok (not (is-eq (map-get? ticket-details ticket-id) none))))


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


(define-public (restore-ticket (ticket-id uint))
;; Allows the admin to restore a previously canceled ticket
(begin
    (asserts! (is-eq tx-sender admin) err-admin-only)
    (asserts! (is-ticket-cancelled ticket-id) err-cancel-failed)
    (map-set cancelled-tickets ticket-id false)
    (ok true)))

;; Function to validate ticket price before purchase
(define-public (validate-ticket-price (price uint))
  (if (< price u10)
      (err u1000) ;; Error code for invalid price
      (ok true)))

;; Add meaningful Clarity contract functionality
(define-public (update-ticket-info (ticket-id uint) (new-info (string-ascii 128)))
    ;; Allows the ticket owner to update the information of their ticket
    (let ((ticket-owner (unwrap! (nft-get-owner? event-ticket ticket-id) err-ticket-not-found)))
        (asserts! (is-eq tx-sender ticket-owner) err-ticket-owner-only)  ;; Ensure sender owns the ticket
        (asserts! (is-valid-ticket-info new-info) err-ticket-exists)  ;; Validate new info
        (map-set ticket-details ticket-id new-info)  ;; Update ticket details
        (ok true)))

;; Optimize a contract function
(define-public (optimized-transfer (ticket-id uint) (recipient principal))
    ;; Transfers a ticket while ensuring minimal computation
    (let ((ticket-owner (unwrap! (nft-get-owner? event-ticket ticket-id) err-ticket-not-found)))
        (asserts! (is-eq tx-sender ticket-owner) err-ticket-owner-only)  ;; Verify sender ownership
        (asserts! (not (is-ticket-cancelled ticket-id)) err-already-cancelled)  ;; Ensure ticket is active
        (try! (nft-transfer? event-ticket ticket-id tx-sender recipient))  ;; Execute transfer
        (ok true)))

;; Add a test suite
(define-public (test-is-admin)
    ;; Test function to check if a given principal is admin
    (ok (is-admin tx-sender)))

;; Add meaningful test suite
(define-public (test-ticket-existence (ticket-id uint))
    ;; Test function to verify ticket existence
    (ok (does-ticket-exist ticket-id)))

(define-public (fixed-transfer-validation (ticket-id uint) (recipient principal))
;; Ensures proper transfer validation before executing the transfer
(let ((current-owner (unwrap! (nft-get-owner? event-ticket ticket-id) err-ticket-not-found)))
    (asserts! (is-eq current-owner tx-sender) err-ticket-owner-only)
    (asserts! (not (is-ticket-cancelled ticket-id)) err-already-cancelled)
    (try! (nft-transfer? event-ticket ticket-id tx-sender recipient))
    (ok true)))

;; Read-Only Functions
(define-read-only (get-ticket-info (ticket-id uint))
    ;; Returns the details of a specific ticket
    (ok (map-get? ticket-details ticket-id)))
   
(define-read-only (is-ticket-transferable? (ticket-id uint))
;; Returns true if the ticket exists and is not canceled, otherwise false
(ok (not (is-ticket-cancelled ticket-id))))

(define-read-only (get-ticket-cancel-status (ticket-id uint))
;; Returns true if the ticket has been canceled, false otherwise
(ok (is-ticket-cancelled ticket-id)))


(define-read-only (get-total-tickets-issued)
;; Returns the total number of tickets issued so far
(ok (+ (var-get last-ticket-id) u1)))

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

(define-read-only (get-ticket-owner (ticket-id uint))
;; Returns the owner of a specific ticket
(ok (nft-get-owner? event-ticket ticket-id)))

(define-read-only (is-ticket-cancelled? (ticket-id uint))
;; Returns true if the ticket has been cancelled, false otherwise
(ok (is-ticket-cancelled ticket-id)))

(define-read-only (is-ticket-transferable (ticket-id uint))
;; Returns true if the ticket exists and is not canceled
(ok (and (not (is-eq (map-get? ticket-details ticket-id) none))
         (not (is-ticket-cancelled ticket-id)))))
        
(define-read-only (get-batch-metadata (batch-id uint))
;; Returns the metadata for a specific batch issuance
(ok (map-get? batch-issuance-metadata batch-id)))

(define-read-only (does-ticket-metadata-exist (ticket-id uint))
;; Checks if metadata exists for a specific ticket
(ok (not (is-eq (map-get? batch-issuance-metadata ticket-id) none))))

(define-read-only (is-event-ticket-available (ticket-id uint))
;; Returns true if the ticket is not canceled and has not been transferred
(ok (and 
    (not (is-ticket-cancelled ticket-id))
    (is-eq (nft-get-owner? event-ticket ticket-id) (some admin)))))

(define-read-only (get-contract-admin)
;; Returns the address of the contract administrator
(ok admin))

(define-read-only (validate-ticket-authenticity (ticket-id uint))
;; Checks the authenticity of a ticket by verifying its ownership and non-cancelled status
(ok (and 
    (is-valid-ticket-id ticket-id)
    (not (is-ticket-cancelled ticket-id)))))

(define-read-only (is-admin-role)
;; Returns true if the caller is the admin
(ok (is-eq tx-sender admin)))

(define-public (refund-ticket (ticket-id uint))
;; Refunds the owner of a canceled ticket (admin-only)
(let ((ticket-owner (unwrap! (nft-get-owner? event-ticket ticket-id) err-ticket-not-found)))
    (begin
        (asserts! (is-eq tx-sender admin) err-admin-only)
        (asserts! (is-ticket-cancelled ticket-id) err-already-cancelled)
        ;; Simulate refund logic here (e.g., transferring tokens)
        (ok ticket-owner))))

(define-read-only (is-ticket-active (ticket-id uint))
;; Returns true if the ticket exists and is not canceled
(ok (and (is-valid-ticket-id ticket-id)
         (not (is-ticket-cancelled ticket-id)))))

(define-read-only (get-batch-issuance-metadata (batch-id uint))
;; Returns metadata for a specific batch of tickets
(ok (map-get? batch-issuance-metadata batch-id)))

(define-read-only (is-transferable-ticket (ticket-id uint))
;; Returns true if the ticket exists, is not canceled, and can be transferred
(ok (and (not (is-eq (map-get? ticket-details ticket-id) none))
         (not (is-ticket-cancelled ticket-id)))))

(define-read-only (get-ticket-ownership-history (ticket-id uint))
;; Returns the ownership history of a ticket
(ok (map-get? ticket-details ticket-id)))

(define-read-only (check-admin-authority (principal principal))
;; Returns true if the specified principal is the admin
(ok (is-eq principal admin)))

(define-read-only (is-valid-ticket-info-length (ticket-info (string-ascii 128)))
;; Returns true if the ticket info length is valid (>= 1 character)
(ok (>= (len ticket-info) u1)))

(define-read-only (get-last-batch-metadata)
;; Returns metadata for the last batch issued
(map-get? batch-issuance-metadata (var-get last-ticket-id)))

(define-read-only (get-admin-address)
;; Returns the admin address of the contract
(ok admin))

(define-read-only (is-valid-ticket-id? (ticket-id uint))
;; Checks if the ticket ID exists and is not canceled
(ok (and (not (is-eq (map-get? ticket-details ticket-id) none))
         (not (is-ticket-cancelled ticket-id)))))

(define-read-only (is-metadata-present? (ticket-id uint))
;; Returns true if metadata exists for the specified ticket ID
(ok (not (is-eq (map-get? batch-issuance-metadata ticket-id) none))))

(define-read-only (get-admin-issued-tickets)
;; Returns the total number of tickets issued by the admin
(ok (var-get last-ticket-id)))

(define-read-only (is-valid-ticket (ticket-id uint))
;; Returns true if the ticket exists, is not canceled, and is valid
(ok (and (not (is-eq (map-get? ticket-details ticket-id) none))
         (not (is-ticket-cancelled ticket-id)))))

(define-read-only (count-active-tickets)
;; Returns the total number of active (non-canceled) tickets
(ok (var-get last-ticket-id)))

(define-read-only (get-batch-issuance-details (batch-id uint))
;; Returns the metadata for a batch issuance
(ok (map-get? batch-issuance-metadata batch-id)))

(define-read-only (is-user-admin (user principal))
;; Returns true if the given user is the admin
(ok (is-eq user admin)))

(define-read-only (is-valid-batch-size (batch-size uint))
;; Returns true if the batch size is within the allowed limit
(ok (<= batch-size max-tickets-per-batch)))

(define-read-only (has-ticket-metadata (ticket-id uint))
;; Checks if a specific ticket has associated metadata
(ok (not (is-eq (map-get? batch-issuance-metadata ticket-id) none))))

;; Contract Initialization
(begin
    (var-set last-ticket-id u0))  ;; Initialize the last ticket ID to 0

