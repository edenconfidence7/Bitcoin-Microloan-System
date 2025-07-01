(define-constant contract-owner tx-sender)
(define-constant collateral-ratio u150)
(define-constant min-loan-amount u1000000)
(define-constant max-loan-amount u100000000)
(define-constant loan-duration u144)
(define-constant liquidation-penalty u10)

(define-data-var total-loans uint u0)
(define-data-var total-collateral uint u0)

(define-map loans
    { loan-id: uint }
    {
        borrower: principal,
        loan-amount: uint,
        collateral-amount: uint,
        start-height: uint,
        end-height: uint,
        status: (string-ascii 20),
        interest-rate: uint,
    }
)

(define-map borrower-stats
    { borrower: principal }
    {
        total-borrowed: uint,
        active-loans: uint,
        completed-loans: uint,
    }
)

(define-read-only (get-loan (loan-id uint))
    (map-get? loans { loan-id: loan-id })
)

(define-read-only (get-borrower-info (borrower principal))
    (map-get? borrower-stats { borrower: borrower })
)

(define-read-only (calculate-required-collateral (loan-amount uint))
    (/ (* loan-amount collateral-ratio) u100)
)

(define-read-only (is-loan-expired (loan-id uint))
    (match (get-loan loan-id)
        loan (> burn-block-height (get end-height loan))
        false
    )
)

(define-public (request-loan
        (loan-amount uint)
        (collateral-amount uint)
    )
    (let (
            (loan-id (var-get total-loans))
            (required-collateral (calculate-required-collateral loan-amount))
        )
        (asserts! (>= collateral-amount required-collateral) (err u1))
        (asserts!
            (and (>= loan-amount min-loan-amount) (<= loan-amount max-loan-amount))
            (err u2)
        )
        (try! (stx-transfer? collateral-amount tx-sender (as-contract tx-sender)))
        (map-set loans { loan-id: loan-id } {
            borrower: tx-sender,
            loan-amount: loan-amount,
            collateral-amount: collateral-amount,
            start-height: burn-block-height,
            end-height: (+ burn-block-height loan-duration),
            status: "active",
            interest-rate: u5,
        })
        (var-set total-loans (+ loan-id u1))
        (var-set total-collateral
            (+ (var-get total-collateral) collateral-amount)
        )
        (update-borrower-stats tx-sender loan-amount true)
        (ok loan-id)
    )
)

(define-public (repay-loan (loan-id uint))
    (match (get-loan loan-id)
        loan (begin
            (asserts! (is-eq (get borrower loan) tx-sender) (err u3))
            (asserts! (is-eq (get status loan) "active") (err u4))
            (try! (stx-transfer? (get loan-amount loan) tx-sender
                (as-contract tx-sender)
            ))
            (try! (as-contract (stx-transfer? (get collateral-amount loan) (as-contract tx-sender)
                tx-sender
            )))
            (map-set loans { loan-id: loan-id } (merge loan { status: "repaid" }))
            (var-set total-collateral
                (- (var-get total-collateral) (get collateral-amount loan))
            )
            (update-borrower-stats tx-sender u0 false)
            (ok true)
        )
        (err u5)
    )
)

(define-public (liquidate-loan (loan-id uint))
    (match (get-loan loan-id)
        loan (begin
            (asserts! (is-loan-expired loan-id) (err u6))
            (asserts! (is-eq (get status loan) "active") (err u7))
            (let (
                    (penalty-amount (/ (* (get collateral-amount loan) liquidation-penalty) u100))
                    (return-amount (- (get collateral-amount loan) penalty-amount))
                )
                (try! (as-contract (stx-transfer? return-amount (as-contract tx-sender)
                    (get borrower loan)
                )))
                (try! (as-contract (stx-transfer? penalty-amount (as-contract tx-sender)
                    contract-owner
                )))
                (map-set loans { loan-id: loan-id }
                    (merge loan { status: "liquidated" })
                )
                (var-set total-collateral
                    (- (var-get total-collateral) (get collateral-amount loan))
                )
                (update-borrower-stats (get borrower loan) u0 false)
                (ok true)
            )
        )
        (err u8)
    )
)

(define-private (update-borrower-stats
        (borrower principal)
        (loan-amount uint)
        (is-new bool)
    )
    (match (get-borrower-info borrower)
        stats (map-set borrower-stats { borrower: borrower } {
            total-borrowed: (+ (get total-borrowed stats) loan-amount),
            active-loans: (if is-new
                (+ (get active-loans stats) u1)
                (- (get active-loans stats) u1)
            ),
            completed-loans: (if (and (not is-new) (> loan-amount u0))
                (+ (get completed-loans stats) u1)
                (get completed-loans stats)
            ),
        })
        (map-set borrower-stats { borrower: borrower } {
            total-borrowed: loan-amount,
            active-loans: (if is-new
                u1
                u0
            ),
            completed-loans: u0,
        })
    )
)
