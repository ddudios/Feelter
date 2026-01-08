//
//  HotTrendResponseDTO+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

extension HotTrendResponseDTO {
    func toDomain() -> [FilterSummary] {
        return data.map { $0.toSummaryDomain() }
    }
}
