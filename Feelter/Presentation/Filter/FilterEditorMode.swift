//
//  FilterEditorMode.swift
//  Feelter
//
//  Created by Suji Jang on 1/15/26.
//

import Foundation

/// 필터 생성/수정 모드 구분
enum FilterEditorMode {
    /// 새 필터 생성
    case create
    /// 기존 필터 수정
    case edit(FilterDetail)

    var isEditMode: Bool {
        if case .edit = self { return true }
        return false
    }

    var filterDetail: FilterDetail? {
        if case .edit(let detail) = self { return detail }
        return nil
    }

    var navigationTitle: String {
        switch self {
        case .create: return "MAKE"
        case .edit: return "EDIT"
        }
    }
}
