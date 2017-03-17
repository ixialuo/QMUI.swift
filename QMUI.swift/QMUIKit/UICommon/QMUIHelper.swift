//
//  QMUIHelper.swift
//  QMUI.swift
//
//  Created by 伯驹 黄 on 2017/2/9.
//  Copyright © 2017年 伯驹 黄. All rights reserved.
//

protocol QMUIHelperDelegate: class {
    func QMUIHelperPrint(_ log: String)
}

class QMUIHelper {
    
    static let shared = QMUIHelper()
    
    private init() {}
    
    weak var helperDelegate: QMUIHelperDelegate?

    // MARK: - UIApplication
    static func renderStatusBarStyleDark() {
        UIApplication.shared.statusBarStyle = .default
    }

    static func renderStatusBarStyleLight() {
        UIApplication.shared.statusBarStyle = .lightContent
    }

    static func dimmedApplicationWindow() {
        let window = UIApplication.shared.keyWindow
        window?.tintAdjustmentMode = .dimmed
        window?.tintColorDidChange()
    }

    static func resetDimmedApplicationWindow() {
        let window = UIApplication.shared.keyWindow
        window?.tintAdjustmentMode = .normal
        window?.tintColorDidChange()
    }
}

let QMUIResourcesMainBundleName = "QMUIResources.bundle"

// MARK: - QMUI专属
extension QMUIHelper {
    static var resourcesBundle: Bundle? {
        return QMUIHelper.resourcesBundle(with: QMUIResourcesMainBundleName)
    }

    static func image(with name: String) -> UIImage? {
        let bundle = QMUIHelper.resourcesBundle
        return QMUIHelper.image(in: bundle, with: name)
    }
    
    static func resourcesBundle(with bundleName: String) -> Bundle? {
        var bundle = Bundle(path: (Bundle.main.resourcePath ?? "") + "/\(bundleName)")
        if bundle == nil {
            // 动态framework的bundle资源是打包在framework里面的，所以无法通过mainBundle拿到资源，只能通过其他方法来获取bundle资源。
            
            let frameworkBundle = Bundle(for: self)
            if let bundleData = parse(bundleName) {
                bundle = Bundle(path: frameworkBundle.path(forResource: bundleData["name"], ofType: bundleData["type"])!)
            }
        }
        return bundle
    }

    static func image(in bundle: Bundle?, with name: String?) -> UIImage? {
        if let bundle = bundle, let name = name {
            // TODO:
            /*
             if ([UIImage respondsToSelector:@selector(imageNamed:inBundle:compatibleWithTraitCollection:)]) {
             return [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:nil];
             } else {
             NSString *imagePath = [[bundle resourcePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", name]];
             return [UIImage imageWithContentsOfFile:imagePath];
             }
             */
            let imagePath = (bundle.resourcePath ?? "") + "\(name).png"
            return UIImage(contentsOfFile: imagePath)
        }
        return nil
    }

    private static func parse(_ bundleName: String) -> [String: String]? {
        let bundleData = bundleName.components(separatedBy: ".")
        guard bundleData.count == 2 else {
            return nil
            
        }
        return [
            "name": bundleData[0],
            "type": bundleData[1]
        ]
    }
}


// MARK: - DynamicType
extension QMUIHelper {
    /// 返回当前contentSize的level，这个值可以在设置里面的“字体大小”查看，辅助功能里面有个“更大字体”可以设置更大的字体，不过这里我们这个接口将更大字体都做了统一，都返回“字体大小”里面最大值。
    static var preferredContentSizeLevel: Int {
        var index = 0
        if UIApplication.instancesRespond(to: #selector(getter: UIApplication.preferredContentSizeCategory)) {
            let contentSizeCategory = UIApplication.shared.preferredContentSizeCategory

            switch contentSizeCategory {
            case UIContentSizeCategory.extraSmall:
                index = 0
            case UIContentSizeCategory.small:
                index = 1
            case UIContentSizeCategory.medium:
                index = 2
            case UIContentSizeCategory.large:
                index = 3
            case UIContentSizeCategory.extraLarge:
                index = 4
            case UIContentSizeCategory.extraExtraLarge:
                index = 5
            case UIContentSizeCategory.extraExtraExtraLarge:
                index = 6
            case UIContentSizeCategory.accessibilityMedium, UIContentSizeCategory.accessibilityLarge, UIContentSizeCategory.accessibilityExtraLarge, UIContentSizeCategory.accessibilityExtraExtraLarge, UIContentSizeCategory.accessibilityExtraExtraExtraLarge:
                index = 6
            default:
                index = 6
            }
        }
        
        return index
    }

    /// 设置当前cell的高度，heights是有七个数值的数组，对于不支持的iOS版本，则选择中间的值返回。
    static func heightForDynamicTypeCell(_ heights: [CGFloat]) -> CGFloat {
        let index = QMUIHelper.preferredContentSizeLevel
        return heights[index]
    }
}