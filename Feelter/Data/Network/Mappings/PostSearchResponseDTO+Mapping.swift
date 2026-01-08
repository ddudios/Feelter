//
//  PostSearchResponseDTO+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

extension PostSearchResponseDTO {
    func toDomain() -> [PostSummary] {
        return data.map { $0.toSummaryDomain() }
    }
}
