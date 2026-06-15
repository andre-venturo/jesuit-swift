//
//  Injected.swift
//  Jesuit
//
//  Created by admin on 22/11/25.
//

import Swinject

@propertyWrapper
struct Injected<T> {
    let wrappedValue: T

    init() {
        self.wrappedValue = AppDI.shared.resolver(T.self)
    }
}
