////
////  DeepLinkHandler.swift
////  Jesuit
////
////  Created by admin on 22/11/25.
////
//
// import Foundation
//
// class DeepLinkHandler {
//    static func handle(url: URL, navigation: NavigationService) {
//        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
//              let host = components.host else { return }
//
//        switch host {
//        case "profile":
//            navigation.navigate(to: .profile)
//        case "post":
//            if let postId = components.queryItems?.first(where: { $0.name == "id" })?.value {
//                navigation.navigate(to: .postDetail(postId: postId))
//            }
//        default:
//            break
//        }
//    }
// }
