//
//  SocketIOManager.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation
import SocketIO
import Combine

/// Socket.IO 에러 타입
enum SocketError: LocalizedError {
    case noToken                    // 토큰이 없음 (로그인 안 함)
    case authenticationFailed       // 인증 실패 (토큰 만료, 잘못된 토큰)
    case connectionFailed           // 연결 실패 (네트워크 에러)
    case disconnected               // 연결 끊김

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "로그인이 필요합니다."
        case .authenticationFailed:
            return "인증이 만료되었습니다. 다시 로그인해주세요."
        case .connectionFailed:
            return "서버 연결에 실패했습니다."
        case .disconnected:
            return "연결이 끊어졌습니다."
        }
    }

    /// 재로그인이 필요한 에러인지 확인
    var requiresReauthentication: Bool {
        switch self {
        case .noToken, .authenticationFailed:
            return true
        case .connectionFailed, .disconnected:
            return false
        }
    }
}

/// Socket.IO 연결 및 이벤트 관리
///
/// 역할:
/// 1. 특정 채팅방에 Socket.IO 연결
/// 2. 서버로부터 실시간 메시지 수신
/// 3. Combine Publisher로 메시지 전달
///
/// 서버 구조:
/// - 연결 URL: `http://{baseURL}:{port}/chats-{room_id}`
/// - 각 채팅방마다 별도 namespace 사용
/// - 이벤트 이름: "chat" (서버가 새 메시지를 push할 때 사용)
///
final class SocketIOManager {

    // MARK: - Properties
    /// 현재 연결된 Socket.IO 클라이언트
    private var socketClient: SocketIOClient?

    /// 현재 연결된 채팅방 ID
    private var currentRoomId: String?

    /// 새 메시지를 publish하는 Subject
    /// - PassthroughSubject: 값을 저장하지 않고 즉시 전달
    private let messageSubject = PassthroughSubject<ChatMessageResponseDTO, Never>()

    /// Socket 에러를 publish하는 Subject
    /// 인증 에러, 연결 에러 등을 Repository에 전달
    private let errorSubject = PassthroughSubject<SocketError, Never>()

    static let shared = SocketIOManager()

    private init() {}

    // MARK: - Public Methods
    /// 특정 채팅방에 Socket.IO 연결
    ///
    /// 동작:
    /// 1. 액세스 토큰 확인 (없으면 .noToken 에러 발생)
    /// 2. 기존 연결이 있으면 해제
    /// 3. 새로운 채팅방 namespace로 연결
    /// 4. "chat" 이벤트 리스너 등록
    ///
    /// 에러 처리:
    /// - 토큰 없음: errorSubject로 .noToken 방출
    /// - 인증 실패: errorSubject로 .authenticationFailed 방출
    ///
    /// - Parameter roomId: 연결할 채팅방 ID
    func connect(to roomId: String) {
        // 1. 토큰 확인 (연결 전 검사)
        guard let token = getAccessToken(), !token.isEmpty else {
            print("Socket.IO 연결 실패: 토큰이 없습니다.")
            errorSubject.send(.noToken)
            return
        }

        // 2. 이미 같은 방에 연결되어 있으면 무시
        if currentRoomId == roomId, socketClient?.status == .connected {
            print("이미 채팅방 \(roomId)에 연결되어 있습니다.")
            return
        }

        // 3. 기존 연결 해제
        disconnect()

        // 4. Socket.IO Manager 생성
        // baseURL 구성: http://{baseURL}:{port}
        let baseURL = Config.baseURL
        let namespace = "/chats-\(roomId)"

        // Socket.IO 연결 설정
        let manager = SocketManager(
            socketURL: baseURL,
            config: [
                .log(false),  // 프로덕션에서는 false, 디버깅 시 true
                .compress,
                .forceWebsockets(true),  // WebSocket만 사용 (polling 비활성화)
                .reconnects(true),  // 자동 재연결
                .reconnectAttempts(-1),  // 무제한 재시도
                .reconnectWait(1),  // 1초 후 재시도
                .connectParams(["token": token])  // 인증 토큰 전달
            ]
        )

        // 5. 특정 namespace의 Socket 클라이언트 생성
        socketClient = manager.socket(forNamespace: namespace)

        // 6. 이벤트 리스너 등록
        setupEventHandlers()

        // 7. 연결 시작
        socketClient?.connect()
        currentRoomId = roomId

        print("Socket.IO 연결 시도: \(baseURL.absoluteString)\(namespace)")
    }

    /// Socket.IO 연결 해제
    func disconnect() {
        guard let socket = socketClient else { return }

        socket.disconnect()
        socket.removeAllHandlers()
        socketClient = nil
        currentRoomId = nil

        print("Socket.IO 연결 해제")
    }

    /// 메시지를 Observable로 제공
    /// Repository에서 subscribe하여 실시간 메시지 수신
    /// - Returns: ChatMessageResponseDTO Publisher
    func observeMessages() -> AnyPublisher<ChatMessageResponseDTO, Never> {
        return messageSubject.eraseToAnyPublisher()
    }

    /// Socket 에러를 Observable로 제공
    ///
    /// Repository/ViewModel에서 subscribe하여 에러 처리
    /// - 인증 에러 (.noToken, .authenticationFailed) -> 재로그인 처리
    /// - 연결 에러 (.connectionFailed, .disconnected) -> 사용자에게 알림
    ///
    /// - Returns: SocketError Publisher
    func observeErrors() -> AnyPublisher<SocketError, Never> {
        return errorSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Methods
    /// Socket.IO 이벤트 리스너 설정
    private func setupEventHandlers() {
        guard let socket = socketClient else { return }

        // 연결 성공 이벤트
        socket.on(clientEvent: .connect) { _, _ in
            print("Socket.IO 연결 성공: \(self.currentRoomId ?? "")")
        }

        // 연결 해제 이벤트
        socket.on(clientEvent: .disconnect) { data, _ in
            print("Socket.IO 연결 해제: \(data)")
        }

        // 연결 에러 이벤트
        socket.on(clientEvent: .error) { [weak self] data, _ in
            print("Socket.IO 에러: \(data)")

            // 인증 에러 감지 (연결 후 거절 처리)
            // Socket.IO 에러 데이터에서 인증 관련 에러 확인
            if let errorArray = data as? [Any],
               let errorDict = errorArray.first as? [String: Any],
               let errorMessage = errorDict["message"] as? String {

                // 인증 관련 키워드 확인
                if errorMessage.contains("auth") ||
                   errorMessage.contains("unauthorized") ||
                   errorMessage.contains("token") {
                    self?.errorSubject.send(.authenticationFailed)
                } else {
                    self?.errorSubject.send(.connectionFailed)
                }
            } else {
                self?.errorSubject.send(.connectionFailed)
            }
        }

        // 재연결 시도 이벤트
        socket.on(clientEvent: .reconnect) { data, _ in
            print("Socket.IO 재연결 시도: \(data)")
        }

        // "chat" 이벤트: 서버가 새 메시지를 push할 때
        socket.on("chat") { [weak self] data, _ in
            guard let self = self else { return }
            self.handleChatEvent(data: data)
        }
    }

    /// "chat" 이벤트 처리
    ///
    /// 서버 응답 형태:
    /// ```json
    /// {
    ///   "chat_id": "66386735e7696bd61fd5ef14",
    ///   "room_id": "6638664652ba24c89bb29379",
    ///   "content": "반갑습니다 :)",
    ///   "createdAt": "9999-05-06T06:04:52.542Z",
    ///   "sender": { ... },
    ///   "files": [...]
    /// }
    /// ```
    ///
    /// - Parameter data: Socket.IO 이벤트 데이터 ([Any])
    private func handleChatEvent(data: [Any]) {
        // 1. data에서 첫 번째 요소 추출 (Dictionary)
        guard let firstElement = data.first else {
            print("chat 이벤트 데이터가 비어있습니다.")
            return
        }

        // 2. Dictionary로 변환
        guard let messageDict = firstElement as? [String: Any] else {
            print("chat 이벤트 데이터가 Dictionary가 아닙니다: \(firstElement)")
            return
        }

        // 3. JSON 직렬화
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: messageDict)

            // 4. DTO로 디코딩
            let decoder = JSONDecoder()
            let messageDTO = try decoder.decode(ChatMessageResponseDTO.self, from: jsonData)

            // 5. Subject로 publish
            messageSubject.send(messageDTO)

            print("새 메시지 수신: \(messageDTO.content)")

        } catch {
            print("chat 이벤트 파싱 실패: \(error.localizedDescription)")
            print("데이터: \(messageDict)")
        }
    }

    /// 액세스 토큰 가져오기
    /// Socket.IO 연결 시 인증을 위해 사용
    /// - Returns: 액세스 토큰 (없으면 nil)
    private func getAccessToken() -> String? {
        // KeychainManager에서 accessToken 가져오기
        return KeychainManager.shared.read(account: "accessToken")
    }
}
