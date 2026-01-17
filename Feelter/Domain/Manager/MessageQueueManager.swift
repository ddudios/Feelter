//
//  MessageQueueManager.swift
//  Feelter
//
//  Created by Claude on 1/18/26.
//

import Foundation

/// 메시지 전송 대기열 관리자
///
/// 역할:
/// 1. 실패한 메시지와 새 메시지를 순차적으로 전송 (FIFO)
/// 2. 네트워크 끊김 시 전송 중단
/// 3. 전송 중 사용자 메시지는 대기열 맨 뒤에 추가
///
actor MessageQueueManager {

    // MARK: - Nested Types

    /// 대기열에 들어갈 메시지 아이템
    struct QueueItem {
        let messageId: String  // 실패 메시지의 경우 기존 ID, 새 메시지는 임시 ID
        let content: String
        let files: [String]
        let isRetry: Bool  // 재전송 여부
    }

    // MARK: - Properties

    /// 전송 대기열 (FIFO)
    private var queue: [QueueItem] = []

    /// 현재 전송 중 여부
    private var isSending: Bool = false

    /// 전송 중단 플래그 (네트워크 끊김 시)
    private var shouldStop: Bool = false

    // MARK: - Public Methods

    /// 대기열에 아이템 추가
    ///
    /// - Parameter item: 전송할 메시지 아이템
    func enqueue(_ item: QueueItem) {
        queue.append(item)
    }

    /// 대기열이 비어있는지 확인
    ///
    /// - Returns: 비어있으면 true
    func isEmpty() -> Bool {
        return queue.isEmpty
    }

    /// 전송 중인지 확인
    ///
    /// - Returns: 전송 중이면 true
    func isCurrentlySending() -> Bool {
        return isSending
    }

    /// 대기열 처리 시작
    ///
    /// - Parameters:
    ///   - repository: 메시지 전송에 사용할 Repository
    ///   - roomId: 채팅방 ID
    ///   - networkMonitor: 네트워크 상태 확인용
    /// - Returns: 성공적으로 전송된 메시지 개수
    func processQueue(
        repository: ChatRepositoryProtocol,
        roomId: String,
        networkMonitor: NetworkMonitor
    ) async -> Int {
        // 이미 전송 중이면 무시
        guard !isSending else {
            return 0
        }

        isSending = true
        shouldStop = false
        var successCount = 0

        while !queue.isEmpty && !shouldStop {
            // 네트워크 상태 확인 (끊겼으면 중단)
            if !networkMonitor.isConnected {
                shouldStop = true
                break
            }

            let item = queue.removeFirst()

            do {
                // 재전송인 경우 기존 메시지 삭제
                if item.isRetry {
                    try await repository.deleteMessage(chatId: item.messageId)
                }

                // 메시지 전송
                _ = try await repository.sendMessage(
                    roomId: roomId,
                    content: item.content,
                    files: item.files
                )

                successCount += 1

            } catch {
                // 네트워크 에러인 경우 전송 중단
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                        shouldStop = true
                        // 실패한 아이템을 다시 큐 맨 앞에 추가 (다음에 재시도)
                        queue.insert(item, at: 0)
                        break
                    default:
                        // 기타 에러는 건너뛰고 계속 진행
                        break
                    }
                }
                // 네트워크 에러가 아닌 경우 (서버 에러 등)는 건너뛰고 계속
            }
        }

        isSending = false
        return successCount
    }

    /// 대기열 초기화
    func clear() {
        queue.removeAll()
        isSending = false
        shouldStop = false
    }

    /// 전송 중단 요청
    func stop() {
        shouldStop = true
    }
}
