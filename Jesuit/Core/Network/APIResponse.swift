//
//  APIResponse.swift
//  Jesuit
//
//  Created by admin on 21/11/25.
//

import Foundation

struct APIResponse<T: Codable & Sendable>: Codable, Sendable {
    let status: String?
    let message: String?
    let code: Int?
    let data: T?
}
