//
//  FilterListResponseDTO+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

extension FilterListResponseDTO {
    func toDomain() -> ([FilterSummary], String?) {
        let filters = data.map { $0.toSummaryDomain() }
        return (filters, nextCursor)
    }
}
