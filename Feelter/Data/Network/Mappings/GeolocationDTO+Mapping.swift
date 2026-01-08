//
//  GeolocationDTO+Mapping.swift
//  Feelter
//
//  Created by Suji Jang on 1/8/26.
//

import Foundation

extension GeolocationDTO {
    func toDomain() -> Geolocation {
        return Geolocation(
            longitude: longitude,
            latitude: latitude
        )
    }
}
