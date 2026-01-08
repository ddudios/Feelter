//
//  TodayFilterResponseDTO+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

extension TodayFilterResponseDTO {
    func toDomain() -> TodayFilter {
        return TodayFilter(
            id: filterId,
            title: title,
            introduction: introduction,
            description: description,
            mainImageURL: files.first ?? "",
            createdAt: createdAt.toDate() ?? Date()
        )
    }
}
