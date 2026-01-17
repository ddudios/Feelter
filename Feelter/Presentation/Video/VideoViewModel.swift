//
//  VideoViewModel.swift
//  Feelter
//
//  Created by Suji Jang on 1/18/26.
//

import Foundation

final class VideoViewModel: ViewModelProtocol {
    
    struct Input {
        
    }
    
    struct Output {
        
    }
    
    private let videoUsecase: VideoUsecaseProtocol
    
    init(videoUsecase: VideoUsecaseProtocol) {
        self.videoUsecase = videoUsecase
    }
    
    func transform(input: Input) -> Output {
        return Output()
    }
}
