# Ticket Management Smart Contract

## Overview

The **Ticket Management Smart Contract** is a Clarity 6.0 contract designed for managing event tickets. It offers functionality for issuing, transferring, canceling, and retrieving information about tickets. The contract supports both single and batch issuance of tickets, with validation checks in place to ensure only authorized actions are performed.

Key features include:
- Admin-controlled ticket issuance and batch processing.
- Ticket cancellation and transfer functionalities.
- Tracking of canceled tickets and batch issuance metadata.
- Read-only functions to retrieve ticket information and ownership status.

## Contract Components

### Constants

- `admin`: The administrator address of the contract.
- `err-admin-only`: Error for non-admin users trying to perform admin-only actions.
- `err-ticket-owner-only`: Error for non-owners attempting to perform actions on a ticket.
- `err-ticket-exists`: Error when attempting to create an invalid or already existing ticket.
- `err-ticket-not-found`: Error when the specified ticket is not found.
- `err-cancel-failed`: Error during ticket cancellation.
- `err-already-cancelled`: Error when attempting to cancel an already canceled ticket.
- `max-tickets-per-batch`: Maximum number of tickets that can be issued in a batch (set to 50).

### Data Variables

- `event-ticket`: A non-fungible token (NFT) representing the event ticket.
- `last-ticket-id`: Tracks the ID of the last ticket issued.
- `ticket-details`: A map that stores details for each ticket using its ID as the key.
- `cancelled-tickets`: A map that tracks canceled tickets.
- `batch-issuance-metadata`: A map that stores metadata related to batch ticket issuance.

## Contract Functions

### Public Functions

#### `issue`

```clary
(define-public (issue (ticket-info (string-ascii 128))))
```

Issues a single ticket. Only the admin can issue tickets. The function validates the ticket info and mints an NFT for the ticket. The `ticket-info` is a string containing ticket details.

- **Requires**: Admin-only permission.
- **Returns**: The ticket ID.

#### `batch-issue`

```clary
(define-public (batch-issue (ticket-infos (list 50 (string-ascii 128)))))
```

Issues multiple tickets (up to 50) in a single batch. The function ensures that only the admin can perform this action, and checks the batch size against the maximum limit.

- **Requires**: Admin-only permission.
- **Returns**: List of issued ticket IDs.

#### `cancel`

```clary
(define-public (cancel (ticket-id uint)))
```

Cancels a specific ticket. The sender must be the ticket owner, and the ticket must not already be canceled.

- **Requires**: Ticket owner permission.
- **Returns**: `true` if the cancellation is successful.

#### `transfer`

```clary
(define-public (transfer (ticket-id uint) (sender principal) (recipient principal)))
```

Transfers a ticket from one user to another. The sender must be the owner of the ticket and the ticket must not be canceled.

- **Requires**: Ticket owner permission.
- **Returns**: `true` if the transfer is successful.

### Read-Only Functions

#### `get-ticket-info`

```clary
(define-read-only (get-ticket-info (ticket-id uint)))
```

Returns the details of a specific ticket by its ID.

- **Returns**: The ticket details.

#### `is-ticket-transferable?`

```clary
(define-read-only (is-ticket-transferable? (ticket-id uint)))
```

Returns whether a specific ticket is transferable (i.e., it exists and is not canceled).

- **Returns**: `true` if the ticket is transferable, `false` otherwise.

#### `get-ticket-cancel-status`

```clary
(define-read-only (get-ticket-cancel-status (ticket-id uint)))
```

Returns whether a specific ticket has been canceled.

- **Returns**: `true` if the ticket is canceled, `false` otherwise.

#### `get-total-tickets-issued`

```clary
(define-read-only (get-total-tickets-issued))
```

Returns the total number of tickets that have been issued so far.

- **Returns**: Total tickets issued.

#### `get-ticket-metadata`

```clary
(define-read-only (get-ticket-metadata (ticket-id uint)))
```

Returns metadata associated with a specific ticket, especially for batch issuance.

- **Returns**: Metadata for the ticket.

## Error Codes

- `u200`: Only the admin can perform this action.
- `u201`: Only the ticket owner can perform this action.
- `u202`: Ticket info is invalid or already exists.
- `u203`: The specified ticket was not found.
- `u204`: Error occurred while canceling the ticket.
- `u205`: The ticket has already been canceled.

## Initialization

Upon contract deployment, the `last-ticket-id` is initialized to `0`.

```clary
(begin
    (var-set last-ticket-id u0))
```

## Usage Example

### 1. Issuing a Single Ticket

Admin can issue a ticket by calling the `issue` function with valid ticket details:

```clary
(issue "VIP Ticket for Concert")
```

### 2. Batch Issuing Tickets

Admin can issue multiple tickets by calling the `batch-issue` function:

```clary
(batch-issue ["VIP Ticket for Concert", "General Admission Ticket"])
```

### 3. Cancelling a Ticket

The owner of a ticket can cancel it by calling the `cancel` function with the ticket ID:

```clary
(cancel 1)
```

### 4. Transferring a Ticket

A ticket owner can transfer their ticket to another user by calling the `transfer` function:

```clary
(transfer 1 sender recipient)
```

## License

This smart contract is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request with your improvements.
```

This README.md file covers the following sections:

- **Overview**: General information about the contract's functionality.
- **Contract Components**: Describes constants, data variables, and maps used in the contract.
- **Contract Functions**: Lists and explains the public functions, including usage examples.
- **Error Codes**: Specifies the error codes used throughout the contract.
- **Initialization**: Explains the contract initialization process.
- **Usage Example**: Provides examples for issuing, canceling, and transferring tickets.
- **License**: States the contract's license (MIT in this case).
- **Contributing**: Encourages others to contribute to the project.

Feel free to modify or expand the content as needed for your specific use case.