//
//  UsageManager.swift
//  ClaudeMeter
//
//  Copyright (c) 2026 puq.ai. All rights reserved.
//  Licensed under the MIT License. See LICENSE file.
//

import Foundation
import Combine

@MainActor
class UsageManager: ObservableObject {
    @Published var usageData: UsageData?
    @Published var prepaidCredits: PrepaidCredits?
    @Published var isLoading: Bool = false
    @Published var error: Error?

    private let apiService: APIServiceProtocol
    private let keychainService: KeychainServiceProtocol
    private let cacheManager: CacheManagerProtocol
    private var isFetching: Bool = false

    /// Web API credentials for fallback (set by AppState from settings)
    var webSessionKey: String = ""
    var webOrganizationId: String = ""

    init(
        apiService: APIServiceProtocol = APIService(),
        keychainService: KeychainServiceProtocol = KeychainService(),
        cacheManager: CacheManagerProtocol = CacheManager.shared
    ) {
        self.apiService = apiService
        self.keychainService = keychainService
        self.cacheManager = cacheManager

        // Load cached data on init
        loadCachedData()
    }

    // MARK: - Data Invalidation

    /// Invalidate stale data so UI shows loading state instead of outdated values
    func invalidateStaleData() {
        usageData = nil
        error = nil
        isLoading = true
        print("UsageManager: Stale data invalidated, UI will show loading state")
    }

    // MARK: - Fetch Usage

    func fetchUsage() async {
        guard !isFetching else {
            print("UsageManager: Fetch already in progress, skipping")
            return
        }
        isFetching = true
        defer { isFetching = false }

        isLoading = true
        error = nil

        await DebugLogger.shared.log(.info, "Fetch started")

        do {
            // 1. Get Token
            guard let credentials = try keychainService.getCredentials() else {
                throw AppError.noCredentials
            }

            guard credentials.isValid else {
                await DebugLogger.shared.log(.error, "Token expired", detail: "Expires: \(credentials.expiresAt)")
                throw AppError.credentialsExpired
            }

            await DebugLogger.shared.log(.info, "Token OK, expires \(credentials.expiresAt)", detail: "Type: \(credentials.subscriptionType)")

            // 2. Fetch Data with retry
            let data = try await apiService.fetchUsageWithRetry(token: credentials.accessToken)

            // 3. Update State
            self.usageData = data
            self.error = nil
            cacheManager.cacheUsageData(data)

            // 4. Fetch prepaid credits (best-effort, requires web credentials)
            await fetchCredits()

            await DebugLogger.shared.log(.info, "Fetch success (OAuth API)")

        } catch let error as APIError {
            await DebugLogger.shared.log(.error, "OAuth API failed: \(error.localizedDescription ?? "unknown")")

            // Try web API fallback before giving up
            if let fallbackData = await tryWebAPIFallback() {
                self.usageData = fallbackData
                self.error = nil
                cacheManager.cacheUsageData(fallbackData)
                await fetchCredits()
                await DebugLogger.shared.log(.fallback, "Fallback success, using web API data")
                isLoading = false
                return
            }

            self.error = AppError.from(error)
            loadCachedData()
            if self.usageData != nil {
                await DebugLogger.shared.log(.cache, "Using cached data")
            }

        } catch let error as KeychainError {
            self.error = AppError.from(error)
            await DebugLogger.shared.log(.error, "Keychain error: \(error)")

        } catch let error as AppError {
            self.error = error
            await DebugLogger.shared.log(.error, "App error: \(error)")
            if error.shouldRetry {
                loadCachedData()
            }

        } catch {
            self.error = AppError.unknown(error.localizedDescription)
            await DebugLogger.shared.log(.error, "Unknown error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Web API Fallback

    private func tryWebAPIFallback() async -> UsageData? {
        guard !webSessionKey.isEmpty, !webOrganizationId.isEmpty else {
            return nil
        }
        do {
            let data = try await apiService.fetchUsageFromWeb(sessionKey: webSessionKey, organizationId: webOrganizationId)
            return data
        } catch {
            print("UsageManager: Web API fallback failed - \(error)")
            return nil
        }
    }

    // MARK: - Prepaid Credits

    private func fetchCredits() async {
        guard !webSessionKey.isEmpty, !webOrganizationId.isEmpty else {
            return
        }
        do {
            let credits = try await apiService.fetchCreditsFromWeb(sessionKey: webSessionKey, organizationId: webOrganizationId)
            self.prepaidCredits = credits
        } catch {
            await DebugLogger.shared.log(.error, "Credits fetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Cache

    private func loadCachedData() {
        if let cached = cacheManager.getCachedUsageData(maxAge: nil) {
            // Only use cache if we don't have fresh data
            if usageData == nil {
                usageData = cached
            }
        }
    }

    /// Force refresh, ignoring cache
    func forceRefresh() async {
        cacheManager.clearCache()
        await fetchUsage()
    }

    // MARK: - Credentials Check

    var hasCredentials: Bool {
        return keychainService.hasCredentials()
    }

    func validateCredentials() async -> Bool {
        guard let credentials = try? keychainService.getCredentials() else {
            return false
        }
        return await apiService.validateToken(credentials.accessToken)
    }
}
