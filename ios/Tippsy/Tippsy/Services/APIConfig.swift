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
    static var baseURL: String {
        switch AppEnvironment.current {
        case .development:
            return "http://localhost:8080"
        case .production:
            return "https://api.tippsy.app" // TODO: real production URL
        }
    }
}
