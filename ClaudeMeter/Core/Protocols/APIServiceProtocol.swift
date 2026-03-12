//
//  APIServiceProtocol.swift
//  ClaudeMeter
//
//  Copyright (c) 2026 puq.ai. All rights reserved.
//  Licensed under the MIT License. See LICENSE file.
//

import Foundation

/// Protocol defining the API service interface for fetching usage data
protocol APIServiceProtocol {
    /// Fetch usage data without retry
    /// - Parameter token: The authentication token
    /// - Returns: UsageData from the API
    func fetchUsage(token: String) async throws -> UsageData

    /// Fetch usage data with automatic retry and exponential backoff
    /// - Parameter token: The authentication token
    /// - Returns: UsageData from the API
    func fetchUsageWithRetry(token: String) async throws -> UsageData

    /// Validate if a token is valid
    /// - Parameter token: The authentication token to validate
    /// - Returns: True if the token is valid
    func validateToken(_ token: String) async -> Bool

    /// Fetch usage data from the web API (claude.ai) as a fallback
    /// - Parameters:
    ///   - sessionKey: The session cookie value
    ///   - organizationId: The organization UUID
    /// - Returns: UsageData from the web API
    func fetchUsageFromWeb(sessionKey: String, organizationId: String) async throws -> UsageData

    /// Fetch prepaid credits from the web API (claude.ai)
    /// - Parameters:
    ///   - sessionKey: The session cookie value
    ///   - organizationId: The organization UUID
    /// - Returns: PrepaidCredits from the web API
    func fetchCreditsFromWeb(sessionKey: String, organizationId: String) async throws -> PrepaidCredits
}
