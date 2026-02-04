//
//  PaymentViewModel.swift
//  Feelter
//
//  Created by Suji Jang on 1/10/26.
//

import Foundation
import Combine

final class PaymentViewModel: ViewModelProtocol {

    // MARK: - Loading State

    enum LoadingState {
        case idle
        case creatingOrder
        case validatingPayment

        var message: String {
            switch self {
            case .idle:
                return ""
            case .creatingOrder:
                return "주문 생성 중..."
            case .validatingPayment:
                return "결제 확인 중..."
            }
        }
    }

    // MARK: - Input & Output

    struct Input {
        /// "구매하기" 버튼 탭 이벤트
        let didTapPurchaseButton: AnyPublisher<Void, Never>

        /// 아임포트(포트원) 결제 모듈이 닫힌 후 결과 수신 (성공여부, imp_uid, 에러메시지)
        let iamportResponseReceived: AnyPublisher<(success: Bool, impUid: String?, errorMsg: String?), Never>
    }

    struct Output {
        /// 로딩 상태 (메시지 포함)
        let loadingState: AnyPublisher<LoadingState, Never>

        /// 에러 메시지 표시 (Alert용)
        let showError: AnyPublisher<String, Never>

        /// [Step 1 성공] 아임포트 SDK 실행 요청 (주문정보 전달)
        let requestIamportPayment: AnyPublisher<OrderInfo, Never>

        /// [Step 3 성공] 최종 결제 및 검증 완료 (다음 화면으로 이동)
        let paymentDidFinish: AnyPublisher<PaymentValidationResult, Never>
    }

    // MARK: - Properties
    private let usecase: PaymentUsecaseProtocol
    private let filterId: String
    private let price: Int

    /// 미완료 결제 복구를 위한 기존 주문 정보
    /// - nil: 새로운 결제 (createOrder 호출)
    /// - non-nil: 기존 주문 재사용 (createOrder 건너뛰고 바로 PG 결제)
    private let existingOrder: (orderCode: String, totalPrice: Int)?

    private var cancellables = Set<AnyCancellable>()

    private let loadingStateSubject = CurrentValueSubject<LoadingState, Never>(.idle)
    private let showErrorSubject = PassthroughSubject<String, Never>()
    private let requestIamportPaymentSubject = PassthroughSubject<OrderInfo, Never>()
    private let paymentDidFinishSubject = PassthroughSubject<PaymentValidationResult, Never>()

    // 결제 진행 상태 관리 (중복 결제 방지)
    private var isPaymentInProgress = false

    // MARK: - Initializer
    init(
        usecase: PaymentUsecaseProtocol,
        filterId: String,
        price: Int,
        existingOrder: (orderCode: String, totalPrice: Int)? = nil
    ) {
        self.usecase = usecase
        self.filterId = filterId
        self.price = price
        self.existingOrder = existingOrder
    }

    // MARK: - Transform
    func transform(input: Input) -> Output {

        // 1. 구매 버튼 탭 -> 기존 주문 재사용 or 새 주문 생성
        input.didTapPurchaseButton
            .sink { [weak self] in
                guard let self else { return }

                if let existingOrder = self.existingOrder {
                    // 기존 주문 재사용 (createOrder 건너뛰기)
                    self.startPaymentWithExistingOrder(existingOrder)
                } else {
                    // 새 주문 생성
                    self.createOrder()
                }
            }
            .store(in: &cancellables)

        // 2. 아임포트 결과 수신 -> 검증 로직 또는 에러 처리
        input.iamportResponseReceived
            .sink { [weak self] (success, impUid, errorMsg) in
                guard let self else { return }

                // 결제 진행 플래그 해제 (성공/실패 모두)
                PaymentStateManager.shared.clearPaymentInProgress()

                if success, let impUid = impUid {
                    self.validatePayment(impUid: impUid)
                } else {
                    // PG 결제 취소/실패 시 저장된 결제 상태 삭제
                    PaymentStateManager.shared.clearPendingPayment()

                    let message = PaymentErrorMapper.paymentCancelledMessage(reason: errorMsg)
                    self.showErrorSubject.send(message)
                    self.isPaymentInProgress = false
                }
            }
            .store(in: &cancellables)

        return Output(
            loadingState: loadingStateSubject.eraseToAnyPublisher(),
            showError: showErrorSubject.eraseToAnyPublisher(),
            requestIamportPayment: requestIamportPaymentSubject.eraseToAnyPublisher(),
            paymentDidFinish: paymentDidFinishSubject.eraseToAnyPublisher()
        )
    }

    // MARK: - Private Logic

    /// 기존 주문으로 PG 결제 시작 (createOrder 건너뛰기)
    ///
    /// 동작:
    /// 1. 중복 결제 방지 체크
    /// 2. 기존 주문 정보로 OrderInfo 생성
    /// 3. PG 결제 화면 표시 (requestIamportPayment)
    ///
    /// 고려사항:
    /// - 서버에 중복 주문 생성하지 않음 (서버 부하 감소)
    /// - PG사는 중복 merchant_uid 자동 차단 (보안)
    /// - Access Token으로 본인 인증 보장 (AuthenticationInterceptor)
    /// - orderId는 더미값 사용 (PG 결제에는 orderCode만 필요)
    ///
    /// - Parameter existingOrder: 미완료 결제의 주문 정보 (orderCode, totalPrice)
    private func startPaymentWithExistingOrder(_ existingOrder: (orderCode: String, totalPrice: Int)) {
        // 중복 결제 방지
        guard !isPaymentInProgress else {
            return
        }

        isPaymentInProgress = true

        #if DEBUG
        print("✅ [PaymentViewModel] 기존 주문으로 결제 시작: \(existingOrder.orderCode)")
        #endif

        // 기존 주문 정보 가져오기
        guard let pending = PaymentStateManager.shared.getPendingPayment() else {
            // PendingPayment가 없으면 새 주문 생성으로 전환
            isPaymentInProgress = false
            createOrder()
            return
        }

        // createOrder를 건너뛰고 바로 OrderInfo 생성
        // orderId는 빈 문자열 사용 (PG 결제에는 orderCode만 필요)
        let orderInfo = OrderInfo(
            orderId: "",  // PG 결제에는 사용되지 않음
            orderCode: existingOrder.orderCode,
            totalPrice: existingOrder.totalPrice,
            createdAt: pending.createdAt  // UserDefaults에서 가져온 생성 시간
        )

        // PG 결제 화면 표시 (기존 로직과 동일)
        requestIamportPaymentSubject.send(orderInfo)
        loadingStateSubject.send(.idle)
    }

    /// [Step 1] 주문 번호 생성 요청
    /// - 서버에 필터 구매 주문을 생성하고 orderCode(merchant_uid)를 발급받습니다
    /// - 성공 시 아임포트 SDK 실행 요청을 보냅니다
    private func createOrder() {
        // 중복 결제 방지
        guard !isPaymentInProgress else {
            return
        }

        isPaymentInProgress = true
        loadingStateSubject.send(.creatingOrder)

        Task { [weak self] in
            guard let self else { return }
            do {
                let orderInfo = try await self.usecase.createOrder(
                    filterId: self.filterId,
                    price: self.price
                )

                await MainActor.run {
                    // 주문 생성 성공 시 상태 저장 (앱 종료 대비)
                    PaymentStateManager.shared.savePendingPayment(
                        filterId: self.filterId,
                        orderCode: orderInfo.orderCode,
                        totalPrice: orderInfo.totalPrice
                    )

                    self.requestIamportPaymentSubject.send(orderInfo)
                    self.loadingStateSubject.send(.idle)
                }
            } catch let error as NetworkError {
                await MainActor.run {
                    let userMessage = PaymentErrorMapper.mapToUserFriendlyMessage(error)
                    self.showErrorSubject.send(userMessage)
                    self.loadingStateSubject.send(.idle)
                    self.isPaymentInProgress = false
                }
            } catch {
                await MainActor.run {
                    let userMessage = PaymentErrorMapper.mapToUserFriendlyMessage(error)
                    self.showErrorSubject.send(userMessage)
                    self.loadingStateSubject.send(.idle)
                    self.isPaymentInProgress = false
                }
            }
        }
    }

    /// [Step 3] 결제 영수증 검증 요청
    /// - 아임포트에서 받은 imp_uid를 서버로 전송하여 실제 결제 금액과 주문 금액이 일치하는지 검증합니다
    /// - 검증 성공 시 필터 잠금 해제 및 다운로드가 가능해집니다
    /// - 검증 실패 시 결제는 되었지만 서버에서 확인되지 않은 상태이므로 고객센터 안내가 필요할 수 있습니다
    private func validatePayment(impUid: String) {
        loadingStateSubject.send(.validatingPayment)

        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.usecase.validatePayment(impUid: impUid)

                await MainActor.run {
                    // 결제 검증 완료 시 저장된 상태 삭제
                    PaymentStateManager.shared.clearPendingPayment()

                    self.paymentDidFinishSubject.send(result)
                    self.loadingStateSubject.send(.idle)
                    self.isPaymentInProgress = false
                }
            } catch let error as NetworkError {
                await MainActor.run {
                    let userMessage = PaymentErrorMapper.mapToUserFriendlyMessage(error)
                    self.showErrorSubject.send(userMessage)
                    self.loadingStateSubject.send(.idle)
                    self.isPaymentInProgress = false
                }
            } catch {
                await MainActor.run {
                    let userMessage = PaymentErrorMapper.mapToUserFriendlyMessage(error)
                    self.showErrorSubject.send(userMessage)
                    self.loadingStateSubject.send(.idle)
                    self.isPaymentInProgress = false
                }
            }
        }
    }
}
