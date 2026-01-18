//
//  UserRepositoryProtocol.swift
//  Feelter
//
//  Created by Suji Jang on 1/20/26.
//

import Foundation

protocol UserRepositoryProtocol {
    func fetchTodayAuthor() async throws -> TodayAuthor
}
