//
//  NetworkError.swift
//  Jesuit
//
//  Created by admin on 22/11/25.
//

import Foundation

enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError(String)
    case serverError(Int, String?)
    case unauthorized
    case networkFailure(String)
    case unknown

    // ponytail: user-facing copy is Indonesian; technical detail stays in logs, not on screen.
    var localizedDescription: String {
        switch self {
        case .invalidURL, .noData, .decodingError, .unknown:
            return "Terjadi kesalahan. Coba lagi."
        case .serverError(_, let message):
            return message ?? "Server sedang bermasalah. Coba lagi nanti."
        case .unauthorized:
            return "Sesi Anda berakhir. Masuk kembali."
        case .networkFailure:
            return "Tidak ada koneksi internet. Periksa jaringan Anda."
        }
    }
}
