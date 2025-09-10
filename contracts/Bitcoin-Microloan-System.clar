(define-constant contract-owner tx-sender)
(define-constant collateral-ratio u150)
(define-constant min-loan-amount u1000000)
(define-constant max-loan-amount u100000000)
(define-constant loan-duration u144)
(define-constant liquidation-penalty u10)
(define-constant base-interest-rate u3)
(define-constant max-interest-rate u15)
(define-constant credit-score-threshold u10)

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
        defaulted-loans: uint,
        credit-score: uint,
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

(define-read-only (calculate-credit-score (borrower principal))
    (match (get-borrower-info borrower)
        stats (let (
                (completed (get completed-loans stats))
                (defaulted (get defaulted-loans stats))
                (total-history (+ completed defaulted))
            )
            (if (> total-history u0)
                (let ((score (/ (* completed u100) total-history)))
                    (if (> score u100)
                        u100
                        score
                    )
                )
                u50
            )
        )
        u50
    )
)

(define-read-only (calculate-dynamic-interest-rate
        (borrower principal)
        (loan-amount uint)
        (collateral-amount uint)
    )
    (let (
            (credit-score (calculate-credit-score borrower))
            (collateral-bonus (if (> collateral-amount (* loan-amount u2))
                u1
                u0
            ))
            (size-penalty (if (> loan-amount u50000000)
                u2
                u0
            ))
        )
        (let ((calculated-rate (+ base-interest-rate (- u10 (/ credit-score u10)) size-penalty
                (- u0 collateral-bonus)
            )))
            (if (> calculated-rate max-interest-rate)
                max-interest-rate
                calculated-rate
            )
        )
    )
)

(define-public (request-loan
        (loan-amount uint)
        (collateral-amount uint)
    )
    (let (
            (loan-id (var-get total-loans))
            (required-collateral (calculate-required-collateral loan-amount))
            (dynamic-rate (calculate-dynamic-interest-rate tx-sender loan-amount
                collateral-amount
            ))
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
            interest-rate: dynamic-rate,
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
                (update-borrower-stats-liquidated (get borrower loan))
                (ok true)
            )
        )
        (err u8)
    )
)
(define-public (withdraw-excess-collateral (loan-id uint))
    (let (
            (loan (unwrap! (get-loan loan-id) (err u9)))
            (borrower (get borrower loan))
            (loan-amount (get loan-amount loan))
            (current-collateral (get collateral-amount loan))
            (required-collateral (calculate-required-collateral loan-amount))
            (excess (- current-collateral required-collateral))
        )
        (asserts! (is-eq tx-sender borrower) (err u10))
        (asserts! (is-eq (get status loan) "active") (err u11))
        (asserts! (> excess u0) (err u12))
        (try! (as-contract (stx-transfer? excess (as-contract tx-sender) borrower)))
        (map-set loans { loan-id: loan-id }
            (merge loan { collateral-amount: required-collateral })
        )
        (var-set total-collateral (- (var-get total-collateral) excess))
        (ok true)
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
            defaulted-loans: (get defaulted-loans stats),
            credit-score: (calculate-credit-score borrower),
        })
        (map-set borrower-stats { borrower: borrower } {
            total-borrowed: loan-amount,
            active-loans: (if is-new
                u1
                u0
            ),
            completed-loans: u0,
            defaulted-loans: u0,
            credit-score: u50,
        })
    )
)

(define-private (update-borrower-stats-liquidated (borrower principal))
    (match (get-borrower-info borrower)
        stats (map-set borrower-stats { borrower: borrower } {
            total-borrowed: (get total-borrowed stats),
            active-loans: (- (get active-loans stats) u1),
            completed-loans: (get completed-loans stats),
            defaulted-loans: (+ (get defaulted-loans stats) u1),
            credit-score: (calculate-credit-score borrower),
        })
        (map-set borrower-stats { borrower: borrower } {
            total-borrowed: u0,
            active-loans: u0,
            completed-loans: u0,
            defaulted-loans: u1,
            credit-score: u0,
        })
    )
)
