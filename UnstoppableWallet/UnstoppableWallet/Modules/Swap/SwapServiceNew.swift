import Foundation
import EthereumKit
import RxCocoa
import RxSwift
import CoinKit

class SwapServiceNew {
    private let disposeBag = DisposeBag()
    private var swapAdapterDisposeBag = DisposeBag()

    private let swapAdapterManager: SwapAdapterManager
    private let allowanceService: SwapAllowanceService
    private let pendingAllowanceService: SwapPendingAllowanceService
    private let adapterManager: IAdapterManager

    private(set) var state: State = .notReady {
        didSet {
            stateRelay.accept(state)
        }
    }
    private let stateRelay = PublishRelay<State>()

    private(set) var errors: [Error] = [] {
        didSet {
            errorsRelay.accept(errors)
        }
    }
    private let errorsRelay = PublishRelay<[Error]>()

    var balanceFrom: Decimal? {
        didSet {
            balanceFromRelay.accept(balanceFrom)
        }
    }
    private let balanceFromRelay = PublishRelay<Decimal?>()

    var balanceTo: Decimal? {
        didSet {
            balanceToRelay.accept(balanceTo)
        }
    }
    private let balanceToRelay = PublishRelay<Decimal?>()

    var approveData: SwapAllowanceService.ApproveData? {
        balanceFrom.flatMap { allowanceService.approveData(amount: $0) }
    }

    init(swapAdapterManager: SwapAdapterManager, allowanceService: SwapAllowanceService, pendingAllowanceService: SwapPendingAllowanceService, adapterManager: IAdapterManager) {
        self.swapAdapterManager = swapAdapterManager
        self.allowanceService = allowanceService
        self.pendingAllowanceService = pendingAllowanceService
        self.adapterManager = adapterManager

        updateSubscription()
        subscribe(disposeBag, allowanceService.stateObservable) { [weak self] _ in self?.syncState() }
        subscribe(disposeBag, pendingAllowanceService.isPendingObservable) { [weak self] _ in self?.syncState() }
    }

    private func updateSubscription() {
        swapAdapterDisposeBag = DisposeBag()

        subscribe(swapAdapterDisposeBag, swapAdapterManager.swapAdapter.stateObservable) { [weak self] _ in self?.syncState() }
        subscribe(swapAdapterDisposeBag, swapAdapterManager.swapAdapter.fromCoinObservable) { [weak self] coin in self?.sync(coinFrom: coin) }
        subscribe(swapAdapterDisposeBag, swapAdapterManager.swapAdapter.toCoinObservable) { [weak self] coin in self?.sync(coinTo: coin) }
        subscribe(swapAdapterDisposeBag, swapAdapterManager.swapAdapter.fromAmountObservable) { [weak self] _ in self?.syncState() }
        subscribe(swapAdapterDisposeBag, swapAdapterManager.swapAdapter.toAmountObservable) { [weak self] _ in self?.syncState() }
    }

    private func sync(coinFrom: Coin?) {
        balanceFrom = coinFrom.flatMap { balance(coin: $0) }
        allowanceService.set(coin: coinFrom)
        pendingAllowanceService.set(coin: coinFrom)
    }

    private func sync(coinTo: Coin?) {
        balanceTo = coinTo.flatMap { balance(coin: $0) }
    }

    private func syncState() {
        var allErrors = [Error]()
        var loading = false
        var transactionData: TransactionData? = nil

        switch swapAdapterManager.swapAdapter.state {
        case .loading: loading = true
        case let .ready(trade: _, data: data): transactionData = data
        case let .notReady(errors: errors):
            allErrors.append(contentsOf: errors)
        }

        switch allowanceService.state {
        case .loading: loading = true
        case let .ready(allowance: allowance):
            if let fromAmount = swapAdapterManager.swapAdapter.fromAmount, fromAmount > allowance.value {
                allErrors.append(SwapError.insufficientAllowance)
            }
        case let .notReady(error: error):
            allErrors.append(error)
        default: ()
        }

        if let fromAmount = swapAdapterManager.swapAdapter.fromAmount {
            if balanceFrom == nil || (balanceFrom ?? 0) < fromAmount {
                allErrors.append(SwapError.insufficientBalanceFrom)
            }
        }

        if pendingAllowanceService.isPending {
            loading = true
        }

        errors  = allErrors

        if loading {
            state = .loading
        } else if let transactionData = transactionData, errors.isEmpty {
            state = .ready(data: transactionData)
        } else {
            state = .notReady
        }
    }

    private func balance(coin: Coin) -> Decimal? {
        (adapterManager.adapter(for: coin) as? IBalanceAdapter)?.balance
    }

}

extension SwapServiceNew {

    var stateObservable: Observable<State> {
        stateRelay.asObservable()
    }

    var errorsObservable: Observable<[Error]> {
        errorsRelay.asObservable()
    }

    var balanceFromObservable: Observable<Decimal?> {
        balanceFromRelay.asObservable()
    }

    var balanceToObservable: Observable<Decimal?> {
        balanceToRelay.asObservable()
    }
}

extension SwapServiceNew {

    enum State: Equatable {
        case loading
        case ready(data: TransactionData)
        case notReady

        static func ==(lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading): return true
            case (.ready(let lhsTransactionData), .ready(let rhsTransactionData)): return lhsTransactionData == rhsTransactionData
            case (.notReady, .notReady): return true
            default: return false
            }
        }
    }

    enum SwapError: Error {
        case insufficientBalanceFrom
        case insufficientAllowance
        case forbiddenPriceImpactLevel
    }

}
