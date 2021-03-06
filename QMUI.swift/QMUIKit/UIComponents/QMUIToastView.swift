//
//  QMUIToastView.swift
//  QMUI.swift
//
//  Created by 黄伯驹 on 2017/7/10.
//  Copyright © 2017年 伯驹 黄. All rights reserved.
//

enum QMUIToastViewPosition {
    case top
    case center
    case bottom
}

/**
 * `QMUIToastView`是一个用来显示toast的控件，其主要结构包括：`backgroundView`、`contentView`，这两个view都是通过外部赋值获取，默认使用`QMUIToastBackgroundView`和`QMUIToastContentView`。
 *
 * 拓展性：`QMUIToastBackgroundView`和`QMUIToastContentView`是QMUI提供的默认的view，这两个view都可以通过appearance来修改样式，如果这两个view满足不了需求，那么也可以通过新建自定义的view来代替这两个view。另外，QMUI也提供了默认的toastAnimator来实现ToastView的显示和隐藏动画，如果需要重新定义一套动画，可以继承`QMUIToastAnimator`并且实现`QMUIToastViewAnimatorDelegate`中的协议就可以自定义自己的一套动画。
 *
 * 建议使用`QMUIToastView`的时候，再封装一层，具体可以参考`QMUITips`这个类。
 *
 * @see QMUIToastBackgroundView
 * @see QMUIToastContentView
 * @see QMUIToastAnimator
 * @see QMUITips
 */
class QMUIToastView: UIView {

    private weak var hideDelayTimer: Timer?

    /**
     * 生成一个ToastView的唯一初始化方法，`view`的bound将会作为ToastView默认frame。
     *
     * @param view ToastView的superView。
     */
    init(view: UIView) {
        super.init(frame: view.bounds)
        parentView = view

        // 顺序不能乱，先添加backgroundView再添加contentView
        backgroundView = defaultBackgrondView()
        contentView = defaultContentView()

        isOpaque = false
        alpha = 0.0
        backgroundColor = UIColorClear
        layer.allowsGroupOpacity = false

        tintColor = UIColorWhite

        _maskView.backgroundColor = UIColorClear
        addSubview(_maskView)

        NotificationCenter.default.addObserver(self, selector: #selector(statusBarOrientationDidChange), name: .UIApplicationDidChangeStatusBarOrientation, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidChangeStatusBarOrientation, object: nil)
    }

    // MARK: - 横竖屏

    @objc
    private func statusBarOrientationDidChange(_: NSNotification) {
        if parentView == nil {
            return
        }
        setNeedsLayout()
        layoutIfNeeded()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func defaultAnimator() -> QMUIToastAnimator {
        let toastAnimator = QMUIToastAnimator(toastView: self)
        return toastAnimator
    }

    private func defaultBackgrondView() -> QMUIToastBackgroundView {
        let backgroundView = QMUIToastBackgroundView()
        return backgroundView
    }

    private func defaultContentView() -> QMUIToastContentView {
        let contentView = QMUIToastContentView()
        return contentView
    }

    /**
     * parentView是ToastView初始化的时候传进去的那个view。
     */
    private(set) weak var parentView: UIView?

    /**
     * 显示ToastView。
     *
     * @param animated 是否需要通过动画显示。
     *
     * @see toastAnimator
     */
    public func showAnimated(_ animated: Bool) {
        // show之前需要layout以下，防止同一个tip切换不同的状态导致layout没更新
        setNeedsLayout()

        hideDelayTimer?.invalidate()

        alpha = 1.0

        willShowBlock?(parentView, animated)

        if animated {
            if toastAnimator == nil {
                toastAnimator = defaultAnimator()
            }
            toastAnimator?.show() { [weak self] _ in
                self?.didShowBlock?(self?.parentView, animated)
            }
        } else {
            backgroundView?.alpha = 1.0
            contentView?.alpha = 1.0
            didShowBlock?(parentView, animated)
        }
    }

    /**
     * 隐藏ToastView。
     *
     * @param animated 是否需要通过动画隐藏。
     *
     * @see toastAnimator
     */
    public func hideAnimated(_ animated: Bool) {
        willHideBlock?(parentView, animated)

        if animated {
            if toastAnimator == nil {
                toastAnimator = defaultAnimator()
            }
            toastAnimator?.hide() { [weak self] _ in
                self?.didHide(with: animated)
            }
        } else {
            backgroundView?.alpha = 0.0
            contentView?.alpha = 0.0
            didHide(with: animated)
        }
    }

    private func didHide(with animated: Bool) {

        didHideBlock?(parentView, animated)

        hideDelayTimer?.invalidate()
        alpha = 0.0
        if removeFromSuperViewWhenHide {
            removeFromSuperview()
        }
    }

    /**
     * 在`delay`时间后隐藏ToastView。
     *
     * @param animated 是否需要通过动画隐藏。
     * @param delay 多少秒后隐藏。
     *
     * @see toastAnimator
     */
    public func hideAnimated(_ animated: Bool, afterDelay delay: TimeInterval) {
        let timer = Timer(timeInterval: delay, target: self, selector: #selector(handleHideTimer), userInfo: animated, repeats: false)
        RunLoop.current.add(timer, forMode: .commonModes)
        hideDelayTimer = timer
    }

    @objc
    private func handleHideTimer(_ timer: Timer) {
        hideAnimated((timer.userInfo as? Bool) ?? false)
    }

    /// @warning 如果使用 [QMUITips showXxx] 系列快捷方法来显示 tips，willShowBlock 将会在 show 之后才被设置，最终并不会被调用。这种场景建议自己在调用 [QMUITips showXxx] 之前执行一段代码，或者不要使用 [QMUITips showXxx] 的方式显示 tips
    public var willShowBlock: ((UIView?, Bool) -> Void)?
    public var didShowBlock: ((UIView?, Bool) -> Void)?
    public var willHideBlock: ((UIView?, Bool) -> Void)?
    public var didHideBlock: ((UIView?, Bool) -> Void)?

    /**
     * `QMUIToastAnimator`可以让你通过实现一些协议来自定义ToastView显示和隐藏的动画。你可以继承`QMUIToastAnimator`，然后实现`QMUIToastAnimatorDelegate`中的方法，即可实现自定义的动画。如果不赋值，则会使用`QMUIToastAnimator`中的默认动画。
     */
    public var toastAnimator: QMUIToastAnimator?

    /**
     * 决定QMUIToastView的位置，目前有上中下三个位置，默认值是center。

     * 如果设置了top或者bottom，那么ToastView的布局规则是：顶部从marginInsets.top开始往下布局(QMUIToastViewPositionTop) 和 底部从marginInsets.bottom开始往上布局(QMUIToastViewPositionBottom)。
     */
    public var toastPosition: QMUIToastViewPosition = .center

    /**
     * 是否在ToastView隐藏的时候顺便把它从superView移除，默认为false。
     */
    public var removeFromSuperViewWhenHide = false

    ///////////////////

    /**
     * 会盖住整个superView，防止手指可以点击到ToastView下面的内容，默认透明。
     */
    public let _maskView = UIView()

    /** s
     * 承载Toast内容的UIView，可以自定义并赋值给contentView。如果contentView需要跟随ToastView的tintColor变化而变化，可以重写自定义view的`tintColorDidChange`来实现。默认使用`QMUIToastContentView`实现。
     */
    public var contentView: UIView?

    /**
     * `contentView`下面的黑色背景UIView，默认使用`QMUIToastBackgroundView`实现，可以通过`QMUIToastBackgroundView`的 cornerRadius 和 styleColor 来修改圆角和背景色。
     */
    public var backgroundView: UIView?

    ///////////////////

    /**
     * 上下左右的偏移值。
     */
    public var offset: CGPoint = .zero {
        didSet {
            setNeedsLayout()
        }
    }

    /**
     * ToastView距离上下左右的最小间距。
     */
    public var marginInsets: UIEdgeInsets = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20) {
        didSet {
            setNeedsLayout()
        }
    }
}

extension QMUIToastView {
    /**
     * 工具方法。隐藏`view`里面的所有ToastView。
     *
     * @param view 即将隐藏的ToastView的superView。
     * @param animated 是否需要通过动画隐藏。
     *
     * @return 如果成功隐藏一个ToastView则返回YES，失败则NO。
     */
    static func hideAllToast(in view: UIView, animated: Bool) -> Bool {
        let toastViews = allToast(in: view)
        var returnFlag = false
        for toastView in toastViews {
            toastView.removeFromSuperViewWhenHide = true
            toastView.hideAnimated(animated)
            returnFlag = true
        }
        return returnFlag
    }

    /**
     * 工具方法。返回`view`里面最顶级的ToastView，如果没有则返回nil。
     *
     * @param view ToastView的superView。
     * @return 返回一个QMUIToastView的实例。
     */
    static func toast(in view: UIView) -> QMUIToastView? {
        for subview in view.subviews.reversed() {
            if let toastView = subview as? QMUIToastView {
                return toastView
            }
        }
        return nil
    }

    /**
     * 工具方法。返回`view`里面所有的ToastView，如果没有则返回nil。
     *
     * @param view ToastView的superView。
     * @return 包含所有QMUIToastView的数组。
     */
    static func allToast(in view: UIView) -> [QMUIToastView] {
        var toastViews: [QMUIToastView] = []
        for subview in view.subviews {
            if let toastView = subview as? QMUIToastView {
                toastViews.append(toastView)
            }
        }
        return toastViews
    }
}
