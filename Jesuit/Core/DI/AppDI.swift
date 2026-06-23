//
//  AppDI.swift
//  Jesuit
//
//  Created by admin on 21/11/25.
//

import Swinject

class AppDI {
    static let shared = AppDI()
    private let container: Container

    private init() {
        container = Container()

        // Register Network Service
        container.register(NetworkServiceProtocol.self) { _ in
            NetworkService.shared
        }.inObjectScope(.container)

        container.register(NavigationService.self) { _ in
            NavigationService()
        }.inObjectScope(.container)

        // Shared, observable signed-in user state.
        container.register(AuthSession.self) { _ in
            AuthSession()
        }.inObjectScope(.container)

        // Shared root tab selection (drives the tab bar + Quick Create tiles).
        container.register(AppTabRouter.self) { _ in
            AppTabRouter()
        }.inObjectScope(.container)

        // Register repositories
        container.register(AuthRepositoryProtocol.self) { resolver in
            let networkService = resolver.resolve(NetworkServiceProtocol.self)!
            return AuthRepository(network: networkService)
        }.inObjectScope(.container)

        container.register(ContactRepositoryProtocol.self) { resolver in
            let networkService = resolver.resolve(NetworkServiceProtocol.self)!
            return ContactRepository(network: networkService)
        }.inObjectScope(.container)

        container.register(CashReceiptRepositoryProtocol.self) { resolver in
            let networkService = resolver.resolve(NetworkServiceProtocol.self)!
            return CashReceiptRepository(network: networkService)
        }.inObjectScope(.container)

        container.register(DashboardRepositoryProtocol.self) { resolver in
            let networkService = resolver.resolve(NetworkServiceProtocol.self)!
            return DashboardRepository(network: networkService)
        }.inObjectScope(.container)

        // Register Presenter
        container.register(LoginPresenter.self) { resolver in
            LoginPresenter(
                authRepository: resolver.resolve(AuthRepositoryProtocol.self)!,
                session: resolver.resolve(AuthSession.self)!
            )
        }
        container.register(RegisterPresenter.self) { resolver in
            RegisterPresenter(
                authRepository: resolver.resolve(AuthRepositoryProtocol.self)!,
                session: resolver.resolve(AuthSession.self)!
            )
        }
        container.register(ForgotPasswordPresenter.self) { _ in ForgotPasswordPresenter() }
        container.register(ResetPasswordPresenter.self) { _ in ResetPasswordPresenter() }
        container.register(ChangePasswordPresenter.self) { resolver in
            ChangePasswordPresenter(
                authRepository: resolver.resolve(AuthRepositoryProtocol.self)!
            )
        }
        container.register(EditProfilePresenter.self) { resolver in
            EditProfilePresenter(
                authRepository: resolver.resolve(AuthRepositoryProtocol.self)!,
                session: resolver.resolve(AuthSession.self)!
            )
        }
        container.register(HomePresenter.self) { resolver in
            HomePresenter(
                authRepository: resolver.resolve(AuthRepositoryProtocol.self)!,
                dashboardRepository: resolver.resolve(DashboardRepositoryProtocol.self)!,
                session: resolver.resolve(AuthSession.self)!,
                tabRouter: resolver.resolve(AppTabRouter.self)!
            )
        }
        container.register(ContactPresenter.self) { resolver in
            ContactPresenter(
                contactRepository: resolver.resolve(ContactRepositoryProtocol.self)!
            )
        }
        container.register(PenerimaanPresenter.self) { resolver in
            PenerimaanPresenter(
                repository: resolver.resolve(CashReceiptRepositoryProtocol.self)!
            )
        }
        container.register(PengeluaranPresenter.self) { resolver in
            PengeluaranPresenter(
                repository: resolver.resolve(CashReceiptRepositoryProtocol.self)!
            )
        }
        container.register(LaporanPresenter.self) { resolver in
            LaporanPresenter(
                repository: resolver.resolve(CashReceiptRepositoryProtocol.self)!
            )
        }
    }

    func resolver<T>(_ type: T.Type) -> T { container.resolve(type)! }

    /// Builds a cash-receipt detail presenter for a specific transaction id
    /// (the id is per-instance, so it can't be a plain container registration).
    @MainActor
    func cashReceiptDetailPresenter(id: String) -> CashReceiptDetailPresenter {
        CashReceiptDetailPresenter(
            id: id,
            repository: container.resolve(CashReceiptRepositoryProtocol.self)!,
            session: container.resolve(AuthSession.self)!
        )
    }
}

// usage
// statis
// @Injected private var networkService: NetworkServiceProtocol
// dynamic
// @State private var presenter = AppDI.shared.container.resolve(LoginPresenter.self)!
