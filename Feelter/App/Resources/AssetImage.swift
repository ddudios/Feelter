//
//  AssetImage.swift
//  Feelter
//
//  Created by Suji Jang on 1/5/26.
//

import UIKit

extension UIImage {

    private static func template(_ name: String) -> UIImage? {
        UIImage(named: name)?.withRenderingMode(.alwaysTemplate)
    }

    enum TabBar {
        static var homeEmpty: UIImage? { template("Home_Empty") }
        static var homeFill: UIImage? { template("Home_Fill") }
        static var feedEmpty: UIImage? { template("Feed_Empty") }
        static var feedFill: UIImage? { template("Feed_Fill") }
        static var filterEmpty: UIImage? { template("Filter_Empty") } 
        static var filterFill: UIImage? { template("Filter_Fill") }
        static var searchEmpty: UIImage? { template("Search_Empty") }
        static var searchFill: UIImage? { template("Search_Fill") }
        static var profileEmpty: UIImage? { template("Profile_Empty") }
        static var profileFill: UIImage? { template("Profile_Fill") }
    }

    enum Category {
        static var night: UIImage? { template("Night") }
        static var landscape: UIImage? { template("Landscape") }
        static var people: UIImage? { template("People") }
        static var food: UIImage? { template("Food") }
        static var star: UIImage? { template("Star") }
    }

    enum FilterProps {
        static var blackPoint: UIImage? { template("BlackPoint") }
        static var highlights: UIImage? { template("Highlights") }
        static var contrast: UIImage? { template("Contrast") }
        static var vignette: UIImage? { template("Vignette") }
        static var brightness: UIImage? { template("Brightness") }
        static var shadows: UIImage? { template("Shadows") }
        static var saturation: UIImage? { template("Saturation") }
        static var sharpness: UIImage? { template("Sharpness") }
        static var temperature: UIImage? { template("Temperature") }
        static var noise: UIImage? { template("Noise") }
        static var blur: UIImage? { template("Blur") }
        static var exposure: UIImage? { template("Exposure") }
    }

    enum Icon {
        static var undo: UIImage? { template("Undo") }
        static var message: UIImage? { template("Message") }
        static var chevron: UIImage? { template("chevron") }
        static var compare: UIImage? { template("Compare") }
        static var likeFill: UIImage? { template("Like_Fill") }
        static var likeEmpty: UIImage? { template("Like_Empty") }
        static var redo: UIImage? { template("Redo") }
        static var lock: UIImage? { template("Lock") }
        static var save: UIImage? { template("Save") }
        static var noLocation: UIImage? { template("NoLocation") }
        static var add: UIImage? { template("Add") }
    }
}

