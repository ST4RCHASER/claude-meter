//
//  PrepaidCredits.swift
//  ClaudeMeter
//
//  Copyright (c) 2026 puq.ai. All rights reserved.
//  Licensed under the MIT License. See LICENSE file.
//

import Foundation

struct PrepaidCredits: Codable, Equatable {
    let amount: Int              // Remaining credits in cents
    let currency: String
    let pendingInvoiceAmountCents: Int?

    enum CodingKeys: String, CodingKey {
        case amount
        case currency
        case pendingInvoiceAmountCents = "pending_invoice_amount_cents"
    }

    /// Remaining balance in dollars
    var remainingDollars: Double {
        Double(amount) / 100.0
    }

    /// Pending charges in dollars
    var pendingDollars: Double {
        Double(pendingInvoiceAmountCents ?? 0) / 100.0
    }
}
