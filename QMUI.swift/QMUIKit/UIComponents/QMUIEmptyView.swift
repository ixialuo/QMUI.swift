//
//  QMUIEmptyView.swift
//  QMUI.swift
//
//  Created by 伯驹 黄 on 2017/1/23.
//  Copyright © 2017年 伯驹 黄. All rights reserved.
//

protocol QMUIEmptyViewLoadingViewProtocol: class {
    func startAnimating() // 当调用 setLoadingViewHidden:false 时，系统将自动调用此处的 startAnimating
}

extension UIActivityIndicatorView: QMUIEmptyViewLoadingViewProtocol {
}

/**
 *  通用的空界面控件，支持显示 loading、标题和副标题提示语、占位图片，QMUICommonViewController 内已集成一个 emptyView，无需额外添加。
 */
class QMUIEmptyView: UIView {

    // 布局顺序从上到下依次为：imageView, loadingView, textLabel, detailTextLabel, actionButton
    public var loadingView: UIActivityIndicatorView! {
        didSet {
            if loadingView != oldValue {
                oldValue.removeFromSuperview()
                contentView.addSubview(loadingView)
            }
            setNeedsLayout()
        }
    } // 此控件通过设置 loadingView.hidden 来控制 loadinView 的显示和隐藏，因此请确保你的loadingView 没有类似于 hidesWhenStopped = true 之类会使 view.hidden 失效的属性
    public private(set) lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        return imageView
    }()

    public private(set) lazy var textLabel: UILabel = {
        let textLabel = UILabel()
        textLabel.textAlignment = .center
        textLabel.numberOfLines = 0
        return textLabel
    }()

    public private(set) var detailTextLabel: UILabel = {
        let detailTextLabel = UILabel()
        detailTextLabel.textAlignment = .center
        detailTextLabel.numberOfLines = 0
        return detailTextLabel
    }()

    public private(set) var actionButton: UIButton = {
        let actionButton = UIButton()
        actionButton.qmui_outsideEdge = UIEdgeInsets(top: -20, left: -20, bottom: -20, right: -20)
        return actionButton
    }()

    // 可通过调整这些insets来控制间距

    /// 默认为(0, 0, 36, 0)
    public var imageViewInsets = UIEdgeInsets(top: 0, left: 0, bottom: 36, right: 0) {
        didSet {
            setNeedsLayout()
        }
    }

    /// 默认为(0, 0, 36, 0)
    public var loadingViewInsets = UIEdgeInsets(top: 0, left: 0, bottom: 36, right: 0)

    /// 默认为(0, 0, 10, 0)
    public var textLabelInsets = UIEdgeInsets(top: 0, left: 0, bottom: 10, right: 0) {
        didSet {
            setNeedsLayout()
        }
    }

    /// 默认为(0, 0, 10, 0)
    public var detailTextLabelInsets = UIEdgeInsets(top: 0, left: 0, bottom: 10, right: 0) {
        didSet {
            setNeedsLayout()
        }
    }

    /// 默认为(0, 0, 0, 0)
    public var actionButtonInsets = UIEdgeInsets.zero {
        didSet {
            setNeedsLayout()
        }
    }

    /// 如果不想要内容整体垂直居中，则可通过调整此属性来进行垂直偏移。默认为-30，即内容比中间略微偏上
    public var verticalOffset: CGFloat = -30 {
        didSet {
            setNeedsLayout()
        }
    }

    // 字体
    /// 默认为15pt系统字体
    public var textLabelFont = UIFontMake(15) {
        didSet {
            textLabel.font = textLabelFont
            setNeedsLayout()
        }
    }

    /// 默认为14pt系统字体
    public var detailTextLabelFont = UIFontMake(14) {
        didSet {
            updateDetailTextLabel(with: detailTextLabel.text)
        }
    }

    /// 默认为15pt系统字体
    public var actionButtonFont = UIFontMake(15) {
        didSet {
            actionButton.titleLabel?.font = actionButtonFont
            setNeedsLayout()
        }
    }

    // 颜色

    /// 默认为(93, 100, 110)
    public var textLabelTextColor = UIColor(r: 93, g: 100, b: 110) {
        didSet {
            textLabel.textColor = textLabelTextColor
        }
    }

    /// 默认为(133, 140, 150)
    public var detailTextLabelTextColor = UIColor(r: 133, g: 140, b: 150) {
        didSet {
            updateDetailTextLabel(with: detailTextLabel.text)
        }
    }

    /// 默认为QMUICMI.buttonTintColor
    public var actionButtonTitleColor = QMUICMI.buttonTintColor {
        didSet {
            actionButton.setTitleColor(actionButtonTitleColor, for: .normal)
        }
    }

    /**
     *  如果要继承QMUIEmptyView并添加新的子 view，则必须：
     *  1. 像其它自带 view 一样添加到 contentView 上
     *  2. 重写sizeThatContentViewFits
     */
    public private(set) lazy var contentView: UIView = {
        UIView()
    }()

    private lazy var scrollView: UIScrollView = { // 保证内容超出屏幕时也不至于直接被clip（比如横屏时)
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.scrollsToTop = false
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10) // 避免 label 直接撑满到屏幕两边，不好看
        return scrollView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        didInitialized()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        didInitialized()
    }

    private func didInitialized() {

        addSubview(scrollView)

        scrollView.addSubview(contentView)

        loadingView = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        loadingView.hidesWhenStopped = false // 此控件是通过loadingView.hidden属性来控制显隐的，如果UIActivityIndicatorView的hidesWhenStopped属性设置为true的话，则手动设置它的hidden属性就会失效，因此这里要置为false
        contentView.addSubview(loadingView)

        contentView.addSubview(imageView)

        contentView.addSubview(textLabel)

        contentView.addSubview(detailTextLabel)

        contentView.addSubview(actionButton)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        scrollView.frame = bounds

        let contentViewSize = sizeThatContentViewFits.flatted

        contentView.frame = CGRect(x: 0, y: scrollView.bounds.midY - contentViewSize.height / 2 + verticalOffset, width: contentViewSize.width, height: contentViewSize.height).flatted

        scrollView.contentSize = CGSize(width: max(scrollView.bounds.width - scrollView.contentInset.horizontalValue, contentViewSize.width), height: max(scrollView.bounds.height - scrollView.contentInset.verticalValue, contentView.frame.maxY))

        var originY: CGFloat = 0

        if !imageView.isHidden {
            imageView.sizeToFit()
            imageView.frame.setXY(contentView.bounds.minXHorizontallyCenter(in: imageView.frame) + imageViewInsets.left - imageViewInsets.right, originY + imageViewInsets.top)
            originY = imageView.frame.maxY + imageViewInsets.bottom
        }

        if !loadingView.isHidden {
            loadingView.frame.setXY(contentView.bounds.minXHorizontallyCenter(in: loadingView.frame) + loadingViewInsets.left - loadingViewInsets.right, originY + loadingViewInsets.top)
            originY = loadingView.frame.maxY + loadingViewInsets.bottom
        }

        if !textLabel.isHidden {
            let labelWidth = contentView.bounds.width - textLabelInsets.horizontalValue
            let labelSize = textLabel.sizeThatFits(CGSize(width: labelWidth, height: CGFloat.greatestFiniteMagnitude))
            textLabel.frame = CGRect(x: textLabelInsets.left, y: originY + textLabelInsets.top, width: labelWidth, height: labelSize.height).flatted
            originY = textLabel.frame.maxY + textLabelInsets.bottom
        }

        if !detailTextLabel.isHidden {
            let labelWidth = contentView.bounds.width - detailTextLabelInsets.horizontalValue
            let labelSize = detailTextLabel.sizeThatFits(CGSize(width: labelWidth, height: CGFloat.greatestFiniteMagnitude))
            detailTextLabel.frame = CGRect(x: detailTextLabelInsets.left, y: originY + detailTextLabelInsets.top, width: labelWidth, height: labelSize.height).flatted
            originY = detailTextLabel.frame.maxY + detailTextLabelInsets.bottom
        }

        if !actionButton.isHidden {
            actionButton.sizeToFit()
            actionButton.frame.setXY(contentView.bounds.minXHorizontallyCenter(in: actionButton.frame) + actionButtonInsets.left, originY + actionButtonInsets.top)
            originY = actionButton.frame.maxY + actionButtonInsets.bottom
        }
    }

    private var sizeThatContentViewFits: CGSize {
        let resultWidth = scrollView.bounds.width - scrollView.contentInset.horizontalValue
        let imageViewHeight = imageView.sizeThatFits(CGSize(width: resultWidth, height: CGFloat.greatestFiniteMagnitude)).height + imageViewInsets.verticalValue
        let loadingViewHeight = loadingView.bounds.height + loadingViewInsets.verticalValue
        let textLabelHeight = textLabel.sizeThatFits(CGSize(width: resultWidth, height: CGFloat.greatestFiniteMagnitude)).height + textLabelInsets.verticalValue
        let detailTextLabelHeight = detailTextLabel.sizeThatFits(CGSize(width: resultWidth, height: CGFloat.greatestFiniteMagnitude)).height + detailTextLabelInsets.verticalValue
        let actionButtonHeight = actionButton.sizeThatFits(CGSize(width: resultWidth, height: CGFloat.greatestFiniteMagnitude)).height + actionButtonInsets.verticalValue

        var resultHeight: CGFloat = 0
        if !imageView.isHidden {
            resultHeight += imageViewHeight
        }
        if !loadingView.isHidden {
            resultHeight += loadingViewHeight
        }
        if !textLabel.isHidden {
            resultHeight += textLabelHeight
        }
        if !detailTextLabel.isHidden {
            resultHeight += detailTextLabelHeight
        }
        if !actionButton.isHidden {
            resultHeight += actionButtonHeight
        }

        return CGSize(width: resultWidth, height: resultHeight)
    }

    func updateDetailTextLabel(with text: String?) {
        if let text = text {
            let string = NSAttributedString(string: text, attributes: [
                NSAttributedStringKey.font: detailTextLabelFont,
                NSAttributedStringKey.foregroundColor: detailTextLabelTextColor,
                NSAttributedStringKey.paragraphStyle: NSMutableParagraphStyle(lineHeight: detailTextLabelFont.pointSize + 10, lineBreakMode: .byWordWrapping, textAlignment: .center),
            ])
            detailTextLabel.attributedText = string
        }
        detailTextLabel.isHidden = text == nil
        setNeedsLayout()
    }

    // 显示或隐藏loading图标
    func setLoadingViewHidden(_ hidden: Bool) {
        loadingView.isHidden = hidden
        if !hidden {
            loadingView.stopAnimating()
        }
        setNeedsLayout()
    }

    /**
     * 设置要显示的图片
     * @param image 要显示的图片，为nil则不显示
     */
    func set(image: UIImage?) {
        imageView.image = image
        imageView.isHidden = image == nil
        setNeedsLayout()
    }

    /**
     * 设置提示语
     * @param text 提示语文本，若为nil则隐藏textLabel
     */
    func setTextLabelText(_ text: String?) {
        textLabel.text = text
        textLabel.isHidden = text == nil
        setNeedsLayout()
    }

    /**
     * 设置详细提示语的文本
     * @param text 详细提示语文本，若为nil则隐藏detailTextLabel
     */
    func setDetailTextLabelText(_ text: String?) {
        updateDetailTextLabel(with: text)
    }

    /**
     * 设置操作按钮的文本
     * @param title 操作按钮的文本，若为nil则隐藏actionButton
     */
    func setActionButtonTitle(_ title: String?) {
        actionButton.setTitle(title, for: .normal)
        actionButton.isHidden = title == nil
        setNeedsLayout()
    }
}
