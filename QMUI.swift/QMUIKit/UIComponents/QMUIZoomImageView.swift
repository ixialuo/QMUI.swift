//
//  QMUIZoomImageView.swift
//  QMUI.swift
//
//  Created by 黄伯驹 on 2017/7/10.
//  Copyright © 2017年 伯驹 黄. All rights reserved.
//

import Photos
import PhotosUI

protocol QMUIZoomImageViewDelegate: class {
    func singleTouch(in zoomingImageView: QMUIZoomImageView, location: CGPoint)
    func doubleTouch(in zoomingImageView: QMUIZoomImageView, location: CGPoint)
    func longPress(in zoomingImageView: QMUIZoomImageView)
    /**
     *  告知 delegate 在视频预览界面里，由于用户点击了空白区域或播放视频等导致了底部的视频工具栏被显示或隐藏
     *  @param didHide 如果为 YES 则表示工具栏被隐藏，NO 表示工具栏被显示了出来
     */
    func zoomImageView(_ imageView: QMUIZoomImageView, didHideVideoToolbar didHide: Bool)

    /// 是否支持缩放，默认为 YES
    func enabledZoomView(in zoomImageView: QMUIZoomImageView) -> Bool

    // 可通过此方法调整视频播放时底部 toolbar 的视觉位置，默认为 {25, 25, 25, 18}
    // 如果同时设置了 QMUIZoomImageViewVideoToolbar 实例的 contentInsets 属性，则这里设置的值将不再生效
    func contentInsets(for videoToolbar: QMUIZoomImageViewVideoToolbar, in zoomingImageView: QMUIZoomImageView) -> UIEdgeInsets
}

extension QMUIZoomImageViewDelegate {
    func singleTouch(in _: QMUIZoomImageView, location _: CGPoint) {}
    func doubleTouch(in _: QMUIZoomImageView, location _: CGPoint) {}
    func longPress(in _: QMUIZoomImageView) {}

    func zoomImageView(_: QMUIZoomImageView, didHideVideoToolbar _: Bool) {}

    func enabledZoomView(in _: QMUIZoomImageView) -> Bool {
        return true
    }

    func contentInsets(for _: QMUIZoomImageViewVideoToolbar, in _: QMUIZoomImageView) -> UIEdgeInsets {
        return UIEdgeInsets(top: 25, left: 25, bottom: 25, right: 18)
    }
}

/**
 *  支持缩放查看静态图片、live photo、视频的控件
 *  默认显示完整图片或视频，可双击查看原始大小，再次双击查看放大后的大小，第三次双击恢复到初始大小。
 *
 *  支持通过修改 contentMode 来控制静态图片和 live photo 默认的显示模式，目前仅支持 UIViewContentModeCenter、UIViewContentModeScaleAspectFill、UIViewContentModeScaleAspectFit，默认为 UIViewContentModeCenter。注意这里的显示模式是基于 viewportRect 而言的而非整个 zoomImageView
 *  @see viewportRect
 *
 *  QMUIZoomImageView 提供最基础的图片预览和缩放功能以及 loading、错误等状态的展示支持，其他功能请通过继承来实现。
 */

class QMUIZoomImageView: UIView {

    public weak var delegate: QMUIZoomImageViewDelegate?

    /**
     * 比如常见的上传头像预览界面中间有一个用于裁剪的方框，则 viewportRect 必须被设置为这个方框在 zoomImageView 坐标系内的 frame，否则拖拽图片或视频时无法正确限制它们的显示范围
     * @note 图片或视频的初始位置会位于 viewportRect 正中间
     * @note 如果想要图片覆盖整个 viewportRect，将 contentMode 设置为 UIViewContentModeScaleAspectFill 即可
     * 如果设置为 CGRectZero 则表示使用默认值，默认值为和整个 zoomImageView 一样大
     */
    public var viewportRect: CGRect = .zero
    
    public var maximumZoomScale: CGFloat = 0
    
    /// 设置当前要显示的图片，会把 livePhoto/video 相关内容清空，因此注意不要直接通过 imageView.image 来设置图片。
    public weak var image: UIImage?
    
    /// 用于显示图片的 UIImageView，注意不要通过 imageView.image 来设置图片，请使用 image 属性。
    public let imageView = UIImageView()
    
    /// 设置当前要显示的 Live Photo，会把 image/video 相关内容清空，因此注意不要直接通过 livePhotoView.livePhoto 来设置
    private var livePhotoStorge: Any?
    @available(iOS 9.1, *)
    public weak var livePhoto: PHLivePhoto? {
        get {
            guard let photo = self.livePhotoStorge as? PHLivePhoto else {
                return nil
            }
            return photo
        }
        set {
            livePhotoStorge = newValue
        }
    }
    
    /// 用于显示 Live Photo 的 view，仅在 iOS 9.1 及以后才有效
    @available(iOS 9.1, *)
    public var livePhotoView: PHLivePhotoView {
        return
    }
    
    /// 设置当前要显示的 video ，会把 image/livePhoto 相关内容清空，因此注意不要直接通过 videoPlayerLayer 来设置
    public weak var videoPlayerItem: AVPlayerItem?
    
    /// 用于显示 video 的 layer
    public weak var videoPlayerLayer: AVPlayerLayer {
        return
    }
    
    // 播放 video 时底部的工具栏，你可通过此属性来拿到并修改上面的播放/暂停按钮、进度条、Label 等的样式
    // @see QMUIZoomImageViewVideoToolbar
    public weak var videoToolbar: QMUIZoomImageViewVideoToolbar {
        return
    }
    
    // 播放 video 时屏幕中央的播放按钮
    public var videoCenteredPlayButton: QMUIButton {
        return
    }
    
    // 可通过此属性修改 video 播放时屏幕中央的播放按钮图片
    public var videoCenteredPlayButtonImage: UIImage?
    
    /// 暂停视频播放
    public func pauseVideo() {
        
    }

    /// 停止视频播放，将播放状态重置到初始状态
    public func endPlayingVideo() {
        
    }
    
    /**
     *  获取当前正在显示的图片/视频在整个 QMUIZoomImageView 坐标系里的 rect（会按照当前的缩放状态来计算）
     */
    public var imageViewRectInZoomImageView: CGRect {
        let imageView = currentContentView
        return convert(imageView?.frame ?? .zero, from: imageView?.superview)
    }

    /**
     *  重置图片或视频的大小，使用的场景例如：相册控件里放大当前图片、划到下一张、再回来，当前的图片或视频应该恢复到原来大小。
     *  注意子类重写需要调一下super。
     */
    public func revertZooming() {
        
    }

    public let emptyView = QMUIEmptyView()
    
    /**
     *  显示一个 loading
     *  @info 注意 cell 复用可能导致当前页面显示一张错误的旧图片/视频，所以一般情况下需要视情况同时将 image/livePhoto/videoPlayerItem 等属性置为 nil 以清除图片/视频的显示
     */
    public func showLoading() {
    }
    
    /**
     *  显示一句提示语
     *  @info 注意 cell 复用可能导致当前页面显示一张错误的旧图片/视频，所以一般情况下需要视情况同时将 image/livePhoto/videoPlayerItem 等属性置为 nil 以清除图片/视频的显示
     */
    public func showEmptyView(with text: String) {
    
    }
    
    /**
     *  将 emptyView 隐藏
     */
    public func hideEmptyView() {
    }
    
    override func didMoveToWindow() {
        // 当 self.window 为 nil 时说明此 view 被移出了可视区域（比如所在的 controller 被 pop 了），此时应该停止视频播放
        if window == nil {
            endPlayingVideo()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var currentContentView: UIView? {
        //        if (_imageView) {
        //            return _imageView
        //        }
        //        if (_livePhotoView) {
        //            return _livePhotoView
        //        }
        //        if (self.videoPlayerView) {
        //            return self.videoPlayerView
        //        }
        return nil
    }
}

class QMUIZoomImageViewVideoToolbar: UIView {
    public let playButton = QMUIButton()
    public let pauseButton = QMUIButton()
    public let slider = QMUISlider()
    public let sliderLeftLabel = UILabel()
    public let sliderRightLabel = UILabel()

    // 可通过调整此属性来调整 toolbar 的视觉位置，默认为 {25, 25, 25, 18}
    // 如果同时实现了 QMUIZoomImageViewDelegate 的 contentInsetsForVideoToolbar:inZoomingImageView: 方法，则此处设置的值会覆盖掉 delegate 中返回的值
    public var contentInsets = UIEdgeInsets(top: 25, left: 25, bottom: 25, right: 18)

    // 可通过这些属性修改 video 播放时屏幕底部工具栏的播放/暂停图标
    public var playButtonImage = QMUIZoomImageViewImageGenerator.smallPlayImage
    public var pauseButtonImage = QMUIZoomImageViewImageGenerator.pauseImage
}

class QMUIZoomImageViewImageGenerator {
    
    private static let iconsColor = UIColor(r: 0, g: 0, b: 0, a: 0.25)
    
    static var largePlayImage: UIImage? {
        let width: CGFloat = 60
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: width), false, 0)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }

        context.setStrokeColor(UIColor(r: 255, g: 255, b: 255, a: 0.75).cgColor)

        // circle outside
        context.setFillColor(iconsColor.cgColor)
        let circleLineWidth: CGFloat = 1
        // consider line width to avoid edge clip
        let circle = UIBezierPath(ovalIn: CGRect(x: circleLineWidth / 2,
                                                 y: circleLineWidth / 2,
                                                 width: width - circleLineWidth,
                                                 height: width - circleLineWidth))
        circle.lineWidth = circleLineWidth
        circle.stroke()
        circle.fill()
        
        // triangle inside
        context.setFillColor(iconsColor.cgColor)
        let triangleLength: CGFloat = width / 2.5
        let triangle = trianglePath(with: triangleLength)
        let offset = UIOffset(horizontal: width / 2 - triangleLength * tan(.pi / 6) / 2, vertical: width / 2 - triangleLength / 2)
        triangle.apply(CGAffineTransform(translationX: offset.horizontal, y: offset.vertical))
        triangle.fill()

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    // @param length of the triangle side
    private static func trianglePath(with length: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: length * cos(.pi / 6), y: length / 2))
        path.addLine(to: CGPoint(x: 0, y: length))
        path.close()
        return path
    }

    static var smallPlayImage: UIImage? {
        // width and height are equal
        let width: CGFloat = 17
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: width), false, 0)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }

        context.setFillColor(iconsColor.cgColor)
        let path = trianglePath(with: width)
        path.fill()

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    static var pauseImage: UIImage? {
        let size = CGSize(width: 12, height: 18)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }

        context.setStrokeColor(iconsColor.cgColor)
        let lineWidth: CGFloat = 2
        let path = UIBezierPath()
        path.move(to: CGPoint(x: lineWidth / 2, y: 0))
        path.addLine(to: CGPoint(x: lineWidth / 2, y: size.height))
        path.move(to: CGPoint(x: size.width - lineWidth / 2, y: 0))
        path.addLine(to: CGPoint(x: size.width - lineWidth / 2, y: size.height))
        path.lineWidth = lineWidth
        path.stroke()

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
