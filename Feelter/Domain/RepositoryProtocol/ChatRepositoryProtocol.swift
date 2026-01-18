//
//  ChatRepositoryProtocol.swift
//  Feelter
//
//  Created by Suji Jang on 1/11/26.
//

import Foundation
import Combine

protocol ChatRepositoryProtocol {

    // MARK: - 채팅방 관리

    /// 채팅방 생성 또는 조회
    /// 1. 상대방(opponent_id)과의 채팅방이 이미 있으면 조회
    /// 2. 없으면 새로 생성
    /// 3. CoreData에 저장
    ///
    /// - Parameter opponentId: 채팅 상대방 user_id
    /// - Returns: 생성되거나 조회된 채팅방
    /// - Throws: 네트워크 에러, 서버 에러
    func createOrFetchChatRoom(opponentId: String) async throws -> ChatRoom

    /// 채팅방 목록 조회
    /// 1. API에서 최신 채팅방 목록 가져오기
    /// 2. CoreData에 저장 (UPSERT)
    /// 3. CoreData에서 조회하여 반환
    /// updatedAt 기준 최신순 (서버가 정렬해서 줌)
    ///
    /// - Returns: 채팅방 배열
    /// - Throws: 네트워크 에러, 서버 에러
    func fetchChatRooms() async throws -> [ChatRoom]

    /// 채팅방 목록 실시간 구독 (Combine)
    /// - ViewModel에서 구독하여 UI 자동 업데이트
    /// - CoreData 변경 시 자동으로 새 값 발행
    ///
    /// - Returns: ChatRoom 배열을 발행하는 Publisher
    func observeChatRooms() -> AnyPublisher<[ChatRoom], Never>

    // MARK: - 메시지 관리
    /// 채팅 내역 조회
    /// 1. CoreData에서 마지막 메시지 시간 조회
    /// 2. API로 그 이후 메시지만 가져오기 (효율성)
    /// 3. CoreData에 저장 (UPSERT - 중복 방지)
    /// 4. CoreData에서 전체 메시지 조회하여 반환
    ///
    /// - Parameter roomId: 채팅방 ID
    /// - Returns: 메시지 배열 (오래된 순)
    /// - Throws: 네트워크 에러, 서버 에러
    func fetchChatHistory(roomId: String) async throws -> [ChatMessage]

    /// 특정 채팅방의 메시지 실시간 구독
    /// - 채팅방 화면에서 구독
    /// - Socket으로 새 메시지 오면 자동 업데이트
    ///
    /// - Parameter roomId: 채팅방 ID
    /// - Returns: ChatMessage 배열을 발행하는 Publisher
    func observeMessages(roomId: String) -> AnyPublisher<[ChatMessage], Never>

    /// 메시지 전송
    /// 1. Optimistic Update: 즉시 CoreData에 저장 (status: .sending)
    /// 2. API 요청
    /// 3. 성공 시: 서버가 준 실제 chat_id로 업데이트 (status: .sent)
    /// 4. 실패 시: status를 .failed로 변경
    ///
    /// - Parameters:
    ///   - roomId: 채팅방 ID
    ///   - content: 메시지 내용
    ///   - files: 첨부 파일 URL 배열
    /// - Returns: 전송된 메시지 (서버 응답)
    /// - Throws: 네트워크 에러, 서버 에러
    func sendMessage(
        roomId: String,
        content: String?,
        files: [String]
    ) async throws -> ChatMessage

    // MARK: - 파일 업로드
    /// 채팅방 파일 업로드
    /// 1. 이미지/파일을 multipart/form-data로 업로드
    /// 2. 서버가 파일 URL 배열 반환
    /// 3. 이 URL을 sendMessage()의 files 파라미터로 사용
    ///
    /// 제약사항:
    /// - 확장자: jpg, png, jpeg, gif, pdf
    /// - 용량: 5MB
    /// - 개수: 5개
    ///
    /// - Parameters:
    ///   - roomId: 채팅방 ID
    ///   - imageData: 업로드할 이미지/파일 데이터 배열
    /// - Returns: 업로드된 파일 URL 배열
    /// - Throws: 네트워크 에러, 서버 에러, 파일 제약 에러
    func uploadFiles(roomId: String, imageData: [Data]) async throws -> [String]

    // MARK: - Socket 연결 관리
    /// 채팅방에 Socket 연결
    /// 1. Socket.IO 연결
    /// 2. 'chat' 이벤트 리스닝 시작
    /// 3. 새 메시지 수신 시 CoreData에 저장 (UPSERT)
    ///
    /// 주의:
    /// - 채팅방 진입 시 호출
    /// - 이미 연결되어 있으면 무시
    ///
    /// - Parameter roomId: 채팅방 ID
    func connectSocket(roomId: String)

    /// Socket 연결 해제
    /// - Socket.IO 연결 종료
    /// - 이벤트 리스너 제거
    ///
    /// 주의:
    /// - 채팅방 나갈 때 호출
    /// - 연결 안 되어 있으면 무시
    func disconnectSocket()

    // MARK: - 로컬 데이터 관리
    /// 채팅방이 CoreData에 존재하는지 확인하고, 없으면 저장
    ///
    /// 사용처:
    /// - 채팅방 진입 시 (메시지 조회 전)
    /// - 메시지를 저장하기 전에 반드시 채팅방이 존재해야 함
    ///
    /// 동작:
    /// - CoreData에서 채팅방 확인
    /// - 없으면 저장 (lastMessage도 함께 저장)
    /// - 있으면 무시
    ///
    /// - Parameter chatRoom: 저장할 채팅방 정보
    /// - Throws: CoreData 에러
    func ensureChatRoomExists(_ chatRoom: ChatRoom) throws

    /// CoreData의 변경사항을 디스크에 저장
    ///
    /// 사용처:
    /// - ensureChatRoomExists 호출 후 즉시 호출하여 relationship 설정 완료 보장
    /// - 메시지 fetch 전에 chatRoom이 디스크에 저장되어 있어야 함
    ///
    /// - Throws: CoreData 에러
    func saveChatRoomContext() throws

    /// 채팅방의 마지막 읽은 시간 업데이트 (로컬 전용)
    ///
    /// 사용처:
    /// - 채팅방 진입 시
    /// - 안 읽은 메시지 계산에 사용
    ///
    /// 동작:
    /// - CoreData의 lastReadAt 업데이트
    /// - 서버로 전송하지 않음 (로컬에서만 관리)
    ///
    /// - Parameter roomId: 채팅방 ID
    func updateLastReadDate(roomId: String) async throws

    /// 메시지 삭제 (CoreData에서만 삭제, 서버에는 영향 없음)
    ///
    /// 사용처:
    /// - 전송 실패한 메시지 재전송 전 기존 메시지 삭제
    ///
    /// - Parameter chatId: 삭제할 메시지 ID
    /// - Throws: CoreData 에러
    func deleteMessage(chatId: String) async throws

    /// 특정 채팅방의 실패한 메시지 조회
    ///
    /// 조건:
    /// - status가 .failed인 메시지만
    /// - 24시간 이내
    /// - 최근 20개까지
    /// - createdAt 오름차순 (FIFO)
    ///
    /// - Parameter roomId: 채팅방 ID
    /// - Returns: 실패한 메시지 배열
    /// - Throws: CoreData 에러
    func fetchFailedMessages(roomId: String) async throws -> [ChatMessage]

    /// 특정 채팅방에 실패한 메시지가 있는지 확인
    ///
    /// - Parameter roomId: 채팅방 ID
    /// - Returns: 실패한 메시지가 있으면 true
    func hasFailedMessages(roomId: String) -> Bool

    /// 전송 실패한 메시지 재전송
    /// 1. CoreData에서 해당 메시지 조회 (status: .failed)
    /// 2. status를 .sending으로 변경
    /// 3. sendMessage() 재호출
    /// 4. 성공/실패에 따라 status 업데이트
    ///
    /// - Parameter chatId: 재전송할 메시지 ID
    /// - Returns: 재전송된 메시지
    /// - Throws: 네트워크 에러, 서버 에러
    func retryFailedMessage(chatId: String) async throws -> ChatMessage
}
