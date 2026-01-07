//
//  FilterRepository.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import Foundation

protocol FilterRepositoryProtocol {
    func fetchTodayFilter() async throws -> TodayFilter
}
