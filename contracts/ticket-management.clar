;; ticket-management.clar
;; A simplified Clarity 6.0 smart contract for managing event tickets

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

(define-private (issue-ticket (ticket-info (string-ascii 128)))
    ;; Issues a new ticket by minting an NFT, storing the ticket info, and updating the last ticket ID
    (let ((ticket-id (+ (var-get last-ticket-id) u1)))
        (asserts! (is-valid-ticket-info ticket-info) err-ticket-exists)  ;; Ensure valid ticket info
        (try! (nft-mint? event-ticket ticket-id tx-sender))  ;; Mint the NFT for the ticket
        (map-set ticket-details ticket-id ticket-info)  ;; Store ticket details
        (var-set last-ticket-id ticket-id)  ;; Update the last ticket ID issued
        (ok ticket-id)))  ;; Return the new ticket ID
