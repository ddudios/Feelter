//
//  ViewModelType.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import Foundation

protocol ViewModelProtocol: AnyObject {
    associatedtype Input
    associatedtype Output

    func transform(input: Input) -> Output
}
