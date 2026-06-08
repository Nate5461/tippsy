//
//  APIConfig.swift
//  Tippsy
//

import Foundation

enum AppEnvironment {
    case development
    case production

    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
}

enum APIConfig {
    /// Your Mac's LAN IP, used when running on a physical device in development.
    /// Update this if your network reassigns the address (`ipconfig getifaddr en0`).
    private static let devLANHost = "192.168.0.23"

    static var baseURL: String {
        switch AppEnvironment.current {
        case .development:
            // On the Simulator, localhost reaches the Mac directly (no LAN/permissions needed).
            // On a physical device, localhost would mean the phone itself, so use the Mac's LAN IP.
            #if targetEnvironment(simulator)
            return "http://localhost:8080"
            #else
            return "http://\(devLANHost):8080"
            #endif
        case .production:
            return "https://api.tippsy.app" // TODO: real production URL
        }
    }
}
