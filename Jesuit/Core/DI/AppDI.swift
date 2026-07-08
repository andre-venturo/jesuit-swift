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

        container.register(FundTransferRepositoryProtocol.self) { resolver in
            let networkService = resolver.resolve(NetworkServiceProtocol.self)!
            return FundTransferRepository(network: networkService)
        }.inObjectScope(.container)

        container.register(AssetRepositoryProtocol.self) { resolver in
            let networkService = resolver.resolve(NetworkServiceProtocol.self)!
            return AssetRepository(network: networkService)
        }.inObjectScope(.container)

        container.register(AccountRepositoryProtocol.self) { resolver in
            let networkService = resolver.resolve(NetworkServiceProtocol.self)!
            return AccountRepository(network: networkService)
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
        // Shared singleton so the dashboard and the organisation switcher (now a
        // top-level route, no longer handed Home's instance) act on one presenter —
        // switching company there updates the dashboard live.
        container.register(HomePresenter.self) { resolver in
            HomePresenter(
                authRepository: resolver.resolve(AuthRepositoryProtocol.self)!,
                dashboardRepository: resolver.resolve(DashboardRepositoryProtocol.self)!,
                session: resolver.resolve(AuthSession.self)!,
                tabRouter: resolver.resolve(AppTabRouter.self)!
            )
        }.inObjectScope(.container)
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
        container.register(TransferPresenter.self) { resolver in
            TransferPresenter(
                repository: resolver.resolve(FundTransferRepositoryProtocol.self)!,
                lookups: resolver.resolve(CashReceiptRepositoryProtocol.self)!
            )
        }
        container.register(AssetPresenter.self) { resolver in
            AssetPresenter(
                repository: resolver.resolve(AssetRepositoryProtocol.self)!,
                lookups: resolver.resolve(CashReceiptRepositoryProtocol.self)!
            )
        }
        container.register(MasterAkunPresenter.self) { resolver in
            MasterAkunPresenter(
                repository: resolver.resolve(AccountRepositoryProtocol.self)!
            )
        }
        // Shared singleton: the More-row badge, the tab-bar badge and the inbox
        // screen all read one instance, so loading/approving in the inbox updates
        // both badges live (the inbox is now a top-level route, so there's no
        // isPresented binding to refresh the badge on dismiss).
        container.register(ApprovalInboxPresenter.self) { resolver in
            ApprovalInboxPresenter(
                repository: resolver.resolve(CashReceiptRepositoryProtocol.self)!
            )
        }.inObjectScope(.container)
        container.register(LaporanPresenter.self) { resolver in
            LaporanPresenter(
                repository: resolver.resolve(CashReceiptRepositoryProtocol.self)!
            )
        }
        container.register(NeracaPresenter.self) { resolver in
            NeracaPresenter(
                repository: resolver.resolve(DashboardRepositoryProtocol.self)!,
                session: resolver.resolve(AuthSession.self)!
            )
        }
        container.register(BukuBesarPresenter.self) { resolver in
            BukuBesarPresenter(
                repository: resolver.resolve(CashReceiptRepositoryProtocol.self)!
            )
        }
        container.register(ArusKasPresenter.self) { resolver in
            ArusKasPresenter(
                repository: resolver.resolve(CashReceiptRepositoryProtocol.self)!
            )
        }
        container.register(LabaRugiPresenter.self) { resolver in
            LabaRugiPresenter(
                repository: resolver.resolve(DashboardRepositoryProtocol.self)!
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

    /// Builds a fund-transfer detail presenter for a specific transfer id.
    @MainActor
    func transferDetailPresenter(id: String) -> TransferDetailPresenter {
        TransferDetailPresenter(
            id: id,
            repository: container.resolve(FundTransferRepositoryProtocol.self)!,
            lookups: container.resolve(CashReceiptRepositoryProtocol.self)!,
            session: container.resolve(AuthSession.self)!
        )
    }

    /// Builds an asset detail presenter for a specific asset id.
    @MainActor
    func assetDetailPresenter(id: String) -> AssetDetailPresenter {
        AssetDetailPresenter(
            id: id,
            repository: container.resolve(AssetRepositoryProtocol.self)!,
            session: container.resolve(AuthSession.self)!
        )
    }
}

// usage
// statis
// @Injected private var networkService: NetworkServiceProtocol
// dynamic
// @State private var presenter = AppDI.shared.container.resolve(LoginPresenter.self)!
