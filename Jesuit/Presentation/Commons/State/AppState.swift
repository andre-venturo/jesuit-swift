//
//  AppState.swift
//  Jesuit
//
//  Created by admin on 25/11/25.
//

import Foundation

enum AppState<T> {
    case idle
    case empty
    case loading
    case refreshing
    case loadmore
    case success(T)
    case error(Error)
}
