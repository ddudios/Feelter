//
//  HomeViewModel.swift
//  Feelter
//
//  Created by Suji Jang on 1/6/26.
//

import Foundation
import Combine

final class HomeViewModel: ViewModelProtocol {
    
    struct Input {
        
    }
    
    struct Output {
        
    }
    
    private let usecase: FilterUsecaseProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(usecase: FilterUsecaseProtocol) {
        self.usecase = usecase
    }
    
    func transform(input: Input) -> Output {
        return Output()
    }
}
