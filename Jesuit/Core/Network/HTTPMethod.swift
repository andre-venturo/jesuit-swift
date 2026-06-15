//
//  HTTPMethod.swift
//  Jesuit
//
//  Created by admin on 22/11/25.
//

import Foundation

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}
