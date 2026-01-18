//
//  UserRepositoryProtocol.swift
//  Feelter
//
//  Created by Suji Jang on 1/20/26.
//

import Foundation

protocol UserRepositoryProtocol {
    func fetchTodayAuthor() async throws -> TodayAuthor
    func fetchMyProfile() async throws -> User
    func fetchProfile(userId: String) async throws -> User
}
