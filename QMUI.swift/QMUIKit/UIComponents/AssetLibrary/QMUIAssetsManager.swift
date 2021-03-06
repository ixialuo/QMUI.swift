//
//  QMUIAssetsManager.swift
//  QMUI.swift
//
//  Created by 黄伯驹 on 2017/7/10.
//  Copyright © 2017年 伯驹 黄. All rights reserved.
//

import Photos
import AssetsLibrary

let EnforceUseAssetsLibraryForTest = false

/// Asset授权的状态
enum QMUIAssetAuthorizationStatus {
    case notUsingPhotoKit // 对于iOS7及以下不支持PhotoKit的系统，没有所谓的“授权状态”，所以定义一个特定的status用于表示这种情况
    case notDetermined // 还不确定有没有授权
    case authorized // 已经授权
    case notAuthorized // 手动禁止了授权
}

typealias QMUIWriteAssetCompletionBlock = ((_ asset: QMUIAsset?, _ error: Error?) -> Void)?

/// 保存图片到指定相册，该方法是一个 C 方法，与系统 ALAssetLibrary 保存图片的 C 方法 UIImageWriteToSavedPhotosAlbum 对应，方便调用
func QMUIImageWriteToSavedPhotosAlbumWithAlbumAssetsGroup(image: UIImage, albumAssetsGroup: QMUIAssetsGroup, completionBlock: QMUIWriteAssetCompletionBlock) {

    QMUIAssetsManager.shared.saveImageWithImageRef(image.cgImage!, albumAssetsGroup: albumAssetsGroup, orientation: image.imageOrientation, completionBlock: completionBlock)
}

/// 保存视频到指定相册，该方法是一个 C 方法，与系统 ALAssetLibrary 保存图片的 C 方法 UISaveVideoAtPathToSavedPhotosAlbum 对应，方便调用
func QMUISaveVideoAtPathToSavedPhotosAlbumWithAlbumAssetsGroup(videoPath: String, albumAssetsGroup: QMUIAssetsGroup, completionBlock: QMUIWriteAssetCompletionBlock) {

    QMUIAssetsManager.shared.saveVideo(withVideoPathURL: URL(fileURLWithPath: videoPath), albumAssetsGroup: albumAssetsGroup, completionBlock: completionBlock)
}

/**
 *  构建 QMUIAssetsManager 这个对象并提供单例的调用方式主要出于下面几点考虑：
 *  1. 由于需要有同时兼顾 ALAssetsLibrary 和 PhotoKit 的保存图片方法，因此保存图片的方法变得比较复杂。
 *     这时有一个不同于 ALAssetsLibrary 和 PhotoKit 的对象去定义这些保存图片的方法会更便于管理这些方法。
 *  2. 如果使用 ALAssetsLibrary 保存图片，那么最终都会调用 ALAssetsLibrary 的一个实例方法，
 *     而 init ALAssetsLibrary 消耗比较大，因此构建一个单例对象，在对象内部 init 一个 ALAssetsLibrary，
 *     需要保存图片到指定相册时建议统一调用这个单例的方法，减少重复消耗。
 *  3. 与上面相似，使用 PhotoKit 获取图片，基本都需要一个 PHCachingImageManager 的实例，为了减少消耗，
 *     所以 QMUIAssetsManager 单例内部也构建了一个 PHCachingImageManager，并且暴露给外面，方便获取
 *     PHCachingImageManager 的实例。
 */
class QMUIAssetsManager {
    static let shared = QMUIAssetsManager()

    private init() {
        _usePhotoKit = EnforceUseAssetsLibraryForTest ? false : IOS_VERSION >= 8.0
        if !_usePhotoKit {
            _alAssetsLibrary = ALAssetsLibrary()
        }
    }

    private var _phCachingImageManager: PHCachingImageManager?

    private var _usePhotoKit = false

    private var _alAssetsLibrary: ALAssetsLibrary?

    var usePhotoKit: Bool {
        return _usePhotoKit
    }

    /// 获取当前应用的“照片”访问授权状态
    static var authorizationStatus: QMUIAssetAuthorizationStatus {
        let status: QMUIAssetAuthorizationStatus
        if QMUIAssetsManager.shared.usePhotoKit {
            // 获取当前应用对照片的访问授权状态
            switch PHPhotoLibrary.authorizationStatus() {
            case .restricted, .denied:
                status = .notAuthorized
            case .notDetermined:
                status = .notDetermined
            default:
                status = .authorized
            }
        } else {
            // 获取当前应用对照片的访问授权状态
            switch ALAssetsLibrary.authorizationStatus() {
            case .restricted, .denied:
                status = .notAuthorized
            case .notDetermined:
                status = .notDetermined
            default:
                status = .authorized
            }
        }
        return status
    }

    /**
     *  调起系统询问是否授权访问“照片”的 UIAlertView
     *  @param handler 授权结束后调用的 block，默认不在主线程上执行，如果需要在 block 中修改 UI，记得dispatch到mainqueue
     */
    static func requestAuthorization(handler: ((QMUIAssetAuthorizationStatus) -> Void)?) {
        if QMUIAssetsManager.shared.usePhotoKit {
            PHPhotoLibrary.requestAuthorization({ phStatus in
                let status: QMUIAssetAuthorizationStatus
                switch phStatus {
                case .restricted, .denied:
                    status = .notAuthorized
                case .notDetermined:
                    status = .notDetermined
                default:
                    status = .authorized
                }
                handler?(status)
            })
        } else {
            QMUIAssetsManager.shared.alAssetsLibrary.enumerateGroupsWithTypes(ALAssetsGroupAll, usingBlock: nil, failureBlock: nil)
            handler?(.notUsingPhotoKit)
        }
    }

    /**
     *  获取所有的相册，在 iOS 8.0 及以上版本中，同时在该方法内部调用了 PhotoKit，可以获取如个人收藏，最近添加，自拍这类“智能相册”
     *
     *  @param contentType               相册的内容类型，设定了内容类型后，所获取的相册中只包含对应类型的资源
     *  @param showEmptyAlbum            是否显示空相册（经过 contentType 过滤后仍为空的相册）
     *  @param showSmartAlbumIfSupported 是否显示"智能相册"（仅 iOS 8.0 及以上版本可以显示“智能相册”）
     *  @param enumerationBlock          参数 resultAssetsGroup 表示每次枚举时对应的相册。枚举所有相册结束后，enumerationBlock 会被再调用一次，
     *                                   这时 resultAssetsGroup 的值为 nil。可以以此作为判断枚举结束的标记。
     */
    func enumerateAllAlbumsWithAlbumContentType(_ contentType: QMUIAlbumContentType, showEmptyAlbum: Bool = false, showSmartAlbumIfSupported: Bool = true, usingBlock enumerationBlock: ((QMUIAssetsGroup?) -> Void)?) {
        if _usePhotoKit {
            // 根据条件获取所有合适的相册，并保存到临时数组中
            let tempAlbumsArray = PHPhotoLibrary.fetchAllAlbumsWithAlbumContentType(contentType, showEmptyAlbum: showEmptyAlbum, showSmartAlbum: showSmartAlbumIfSupported)

            // 创建一个 PHFetchOptions，用于 QMUIAssetsGroup 对资源的排序以及对内容类型进行控制
            let phFetchOptions = PHPhotoLibrary.createFetchOptionsWithAlbumContentType(contentType)

            // 遍历结果，生成对应的 QMUIAssetsGroup，并调用 enumerationBlock
            for phAssetCollection in tempAlbumsArray {
                let assetsGroup = QMUIAssetsGroup(phAssetCollection: phAssetCollection, fetchAssetsOptions: phFetchOptions)
                enumerationBlock?(assetsGroup)
            }

            /**
             *  所有结果遍历完毕，这时再调用一次 enumerationBlock，并传递 nil 作为实参，作为枚举相册结束的标记。
             *  该处理方式也是参照系统 ALAssetsLibrary enumerateGroupsWithTypes 枚举结束的处理。
             */
            enumerationBlock?(nil)
        } else {
            _alAssetsLibrary?.enumerateAllAlbumsWithAlbumContentType(contentType, usingBlock: { group, _ in
                if let group = group {
                    let assetsGroup = QMUIAssetsGroup(alAssetsGroup: group)
                    enumerationBlock?(assetsGroup)
                } else {
                    /**
                     *  枚举结束，与上面 PhotoKit 中的处理相似，再调用一次 enumerationBlock，并传递 nil 作为实参，作为枚举相册结束的标记。
                     *  与系统 ALAssetsLibrary enumerateGroupsWithTypes 本身处理枚举结束的方式保持一致。
                     */
                    enumerationBlock?(nil)
                }
            })
        }
    }

    /**
     *  保存图片或视频到指定的相册
     *
     *  @warning 无论用户保存到哪个自行创建的相册，系统都会在“相机胶卷”相册中同时保存这个图片。
     *           因为系统没有把图片和视频直接保存到指定相册的接口，都只能先保存到“相机胶卷”，从而生成了 Asset 对象，
     *           再把 Asset 对象添加到指定相册中，从而达到保存资源到指定相册的效果。
     *           即使调用 PhotoKit 保存图片或视频到指定相册的新接口也是如此，并且官方 PhotoKit SampleCode 中例子也是表现如此，
     *           因此这应该是一个合符官方预期的表现。
     *  @warning 在支持“智能相册”的系统版本（iOS 8.0 及以上版本）也中无法通过该方法把图片保存到“智能相册”，
     *           “智能相册”只能由系统控制资源的增删。
     */
    func saveImageWithImageRef(_ imageRef: CGImage, albumAssetsGroup: QMUIAssetsGroup, orientation: UIImageOrientation, completionBlock: QMUIWriteAssetCompletionBlock) {
        if _usePhotoKit {
            let albumPhAssetCollection = albumAssetsGroup.phAssetCollection
            // 把图片加入到指定的相册对应的 PHAssetCollection
            PHPhotoLibrary.shared().addImageToAlbum(imageRef, albumAssetCollection: albumPhAssetCollection!, orientation: orientation, completionHandler: { success, creationDate, error in
                if success {
                    let fetchOptions = PHFetchOptions()

                    fetchOptions.predicate = NSPredicate(format: "creationDate = %@", creationDate! as CVarArg)
                    let fetchResult = PHAsset.fetchAssets(in: albumPhAssetCollection!, options: fetchOptions)
                    let phAsset = fetchResult.lastObject
                    let asset = QMUIAsset(phAsset: phAsset!)
                    completionBlock?(asset, error)
                } else {
                    guard let error = error else { return }
                    print("Get PHAsset of image error: \(error)")
                    completionBlock?(nil, error)
                }
            })
        } else {
            let assetGroup = albumAssetsGroup.alAssetsGroup
            alAssetsLibrary.writeImage(toSavedPhotosAlbum: imageRef, albumAssetsGroup: assetGroup!, orientation: orientation, completionBlock: { assetURL, error in
                self.alAssetsLibrary.asset(for: assetURL, resultBlock: { asset in
                    let resultAsset = QMUIAsset(alAsset: asset!)
                    completionBlock?(resultAsset, (error as NSError?)!)
                }, failureBlock: { error in
                    guard let error = error else { return }
                    print("Get ALAsset of image error : \(error)")
                    completionBlock?(nil, error as NSError)
                })
            })
        }
    }

    func saveVideo(withVideoPathURL videoPathURL: URL, albumAssetsGroup: QMUIAssetsGroup, completionBlock: QMUIWriteAssetCompletionBlock) {
        if _usePhotoKit {
            let albumPhAssetCollection = albumAssetsGroup.phAssetCollection
            // 把视频加入到指定的相册对应的 PHAssetCollection
            PHPhotoLibrary.shared().addVideoToAlbum(videoPathURL, albumAssetCollection: albumPhAssetCollection!, albumAssetCollection: { success, creationDate, error in
                if success {
                    let fetchOptions = PHFetchOptions()
                    fetchOptions.predicate = NSPredicate(format: "creationDate = %@", creationDate as CVarArg)
                    let fetchResult = PHAsset.fetchAssets(in: albumPhAssetCollection!, options: fetchOptions)
                    let phAsset = fetchResult.lastObject
                    let asset = QMUIAsset(phAsset: phAsset!)
                    completionBlock?(asset, error)
                } else {
                    print("Get PHAsset of video Error: \(error)")
                    completionBlock?(nil, error)
                }
            })
        } else {
            let assetsGroup = albumAssetsGroup.alAssetsGroup

            alAssetsLibrary.writeVideoAtPath(toSavedPhotosAlbum: videoPathURL, albumAssetsGroup: assetsGroup!, completionBlock: { assetURL, error in
                self.alAssetsLibrary.asset(for: assetURL, resultBlock: { asset in
                    let resultAsset = QMUIAsset(alAsset: asset!)
                    completionBlock?(resultAsset, error! as NSError)
                }, failureBlock: { error in
                    guard let error = error else { return }
                    print("Get ALAsset of video error: \(error)")
                    completionBlock?(nil, error as NSError)
                })
            })
        }
    }

    /// 强制刷新单例中的 ALAssetLibrary，但你的相册资源发生改变时（创建或删除相册）可以手工调用该方法及时更新
    func refreshAssetsLibrary() {
        _alAssetsLibrary = ALAssetsLibrary()
    }

    /// 获取一个 ALAssetsLibrary 的实例
    var alAssetsLibrary: ALAssetsLibrary {
        return _alAssetsLibrary!
    }

    /// 获取一个 PHCachingImageManager 的实例
    var phCachingImageManager: PHCachingImageManager {
        if _phCachingImageManager == nil {
            _phCachingImageManager = PHCachingImageManager()
        }
        return _phCachingImageManager!
    }
}

extension PHPhotoLibrary {
    /**
     *  根据 contentType 的值产生一个合适的 PHFetchOptions，并把内容以资源创建日期排序，创建日期较新的资源排在前面
     *
     *  @param contentType 相册的内容类型
     *
     *  @return 返回一个合适的 PHFetchOptions
     */
    static func createFetchOptionsWithAlbumContentType(_ contentType: QMUIAlbumContentType) -> PHFetchOptions {
        let fetchOptions = PHFetchOptions()
        // 根据输入的内容类型过滤相册内的资源
        switch contentType {
        case .onlyPhoto:
            fetchOptions.predicate = NSPredicate(format: "mediaType = %i", PHAssetMediaType.image.rawValue)
        case .onlyVideo:
            fetchOptions.predicate = NSPredicate(format: "mediaType = %i", PHAssetMediaType.video.rawValue)

        case .onlyAudio:
            fetchOptions.predicate = NSPredicate(format: "mediaType = %i", PHAssetMediaType.audio.rawValue)
        default:
            break
        }
        return fetchOptions
    }

    /**
     *  获取所有相册
     *
     *  @param contentType    相册的内容类型，设定了内容类型后，所获取的相册中只包含对应类型的资源
     *  @param showEmptyAlbum 是否显示空相册（经过 contentType 过滤后仍为空的相册）
     *  @param showSmartAlbum 是否显示“智能相册”
     *
     *  @return 返回包含所有合适相册的数组
     */
    static func fetchAllAlbumsWithAlbumContentType(_ contentType: QMUIAlbumContentType, showEmptyAlbum: Bool, showSmartAlbum: Bool) -> [PHAssetCollection] {
        var tempAlbumsArray: [PHAssetCollection] = []

        // 创建一个 PHFetchOptions，用于创建 QMUIAssetsGroup 对资源的排序和类型进行控制
        let fetchOptions = PHPhotoLibrary.createFetchOptionsWithAlbumContentType(contentType)

        let fetchResult: PHFetchResult<PHAssetCollection>
        if showSmartAlbum {
            // 允许显示系统的“智能相册”
            // 获取保存了所有“智能相册”的 PHFetchResult
            fetchResult = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
        } else {
            // 不允许显示系统的智能相册，但由于在 PhotoKit 中，“相机胶卷”也属于“智能相册”，因此这里从“智能相册”中单独获取到“相机胶卷”
            fetchResult = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .smartAlbumUserLibrary, options: nil)
        }
        // 循环遍历相册列表
        for i in 0 ..< fetchResult.count {
            // 获取一个相册
            let assetCollection = fetchResult[i]
            // 获取相册内的资源对应的 fetchResult，用于判断根据内容类型过滤后的资源数量是否大于 0，只有资源数量大于 0 的相册才会作为有效的相册显示
            let currentFetchResult = PHAsset.fetchAssets(in: assetCollection, options: fetchOptions)
            if currentFetchResult.count > 0 || showEmptyAlbum {
                // 若相册不为空，或者允许显示空相册，则保存相册到结果数组
                // 判断如果是“相机胶卷”，则放到结果列表的第一位
                if assetCollection.assetCollectionSubtype == .smartAlbumUserLibrary {
                    tempAlbumsArray.insert(assetCollection, at: 0)
                } else {
                    tempAlbumsArray.append(assetCollection)
                }
            }
        }

        // 获取所有用户自己建立的相册
        let topLevelUserCollections = PHCollectionList.fetchTopLevelUserCollections(with: nil)
        // 循环遍历用户自己建立的相册
        for i in 0 ..< topLevelUserCollections.count {
            // 获取一个相册
            guard let assetCollection = topLevelUserCollections[i] as? PHAssetCollection else {
                continue
            }
            if showEmptyAlbum {
                // 允许显示空相册，直接保存相册到结果数组中
                tempAlbumsArray.append(assetCollection)
            } else {
                // 不允许显示空相册，需要判断当前相册是否为空
                let fetchResult = PHAsset.fetchAssets(in: assetCollection, options: fetchOptions)
                // 获取相册内的资源对应的 fetchResult，用于判断根据内容类型过滤后的资源数量是否大于 0
                if fetchResult.count > 0 {
                    tempAlbumsArray.append(assetCollection)
                }
            }
        }
        return tempAlbumsArray
    }

    /// 获取一个 PHAssetCollection 中创建日期最新的资源
    static func fetchLatestAssetWithAssetCollection(_ assetCollection: PHAssetCollection) -> PHAsset? {
        let fetchOptions = PHFetchOptions()
        // 按时间的先后对 PHAssetCollection 内的资源进行排序，最新的资源排在数组最后面

        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let fetchResult = PHAsset.fetchAssets(in: assetCollection, options: fetchOptions)
        // 获取 PHAssetCollection 内最后一个资源，即最新的资源
        let latestAsset = fetchResult.lastObject
        return latestAsset
    }

    /**
     *  保存图片或视频到指定的相册
     *
     *  @warning 无论用户保存到哪个自行创建的相册，系统都会在“相机胶卷”相册中同时保存这个图片。
     *           原因请参考 QMUIAssetsManager 对象的保存图片和视频方法的注释。
     *  @warning 无法通过该方法把图片保存到“智能相册”，“智能相册”只能由系统控制资源的增删。
     */
    func addImageToAlbum(_ imageRef: CGImage, albumAssetCollection: PHAssetCollection, orientation: UIImageOrientation, completionHandler: ((Bool, Date?, Error?) -> Void)?) {
        let targetImage = UIImage(cgImage: imageRef, scale: ScreenScale, orientation: orientation)
        var creationDate: Date?

        performChanges({
            // 创建一个以图片生成新的 PHAsset，这时图片已经被添加到“相机胶卷”

            let assetChangeRequest = PHAssetChangeRequest.creationRequestForAsset(from: targetImage)
            assetChangeRequest.creationDate = Date()
            creationDate = assetChangeRequest.creationDate

            if albumAssetCollection.assetCollectionType == .album {
                // 如果传入的相册类型为标准的相册（非“智能相册”和“时刻”），则把刚刚创建的 Asset 添加到传入的相册中。

                // 创建一个改变 PHAssetCollection 的请求，并指定相册对应的 PHAssetCollection
                let assetCollectionChangeRequest = PHAssetCollectionChangeRequest(for: albumAssetCollection)

                /**
                 *  把 PHAsset 加入到对应的 PHAssetCollection 中，系统推荐的方法是调用 placeholderForCreatedAsset ，
                 *  返回一个的 placeholder 来代替刚创建的 PHAsset 的引用，并把该引用加入到一个 PHAssetCollectionChangeRequest 中。
                 */
                assetCollectionChangeRequest?.addAssets(assetChangeRequest.placeholderForCreatedAsset as! NSFastEnumeration)
            }
        }, completionHandler: { success, error in
            if !success, let error = error {
                print("Creating asset of image error : \(error)")
            }
            guard let completionHandler = completionHandler else { return }
            DispatchQueue.main.async {
                completionHandler(success, creationDate, error)
            }
        })
    }

    func addVideoToAlbum(_: URL, albumAssetCollection _: PHAssetCollection, albumAssetCollection _: ((Bool, Date, NSError) -> Void)?) {
    }
}

extension ALAssetsLibrary {
    /**
     *  获取所有相册
     *
     *  @param contentType      相册的内容类型，设定了内容类型后，所获取的相册中只包含对应类型的资源
     *  @param enumerationBlock 参数 group 表示每次枚举时对应的相册。枚举所有相册结束后，enumerationBlock 会被再调用一次，
     *                          这时 group 的值为 nil。可以以此作为判断枚举结束的标记。
     */
    func enumerateAllAlbumsWithAlbumContentType(_ contentType: QMUIAlbumContentType, usingBlock enumerationBlock: ALAssetsLibraryGroupsEnumerationResultsBlock?) {
        enumerateGroups(withTypes: ALAssetsGroupType(ALAssetsGroupAll), using: { group, stop in
            if let group = group {
                // 根据输入的内容类型过滤相册内的资源，过滤后 group.numberOfAssets 的值会由自动被更新
                switch contentType {
                case .onlyPhoto:
                    group.setAssetsFilter(ALAssetsFilter.allPhotos())
                case .onlyVideo:
                    group.setAssetsFilter(ALAssetsFilter.allVideos())
                default:
                    break
                }

                if group.numberOfAssets() > 0 {
                    enumerationBlock?(group, stop)
                }
            } else {
                /**
                 *  枚举结束，再调用一次 enumerationBlock，并传递 nil 作为实参，作为枚举相册结束的标记。
                 *  与系统 ALAssetsLibrary enumerateGroupsWithTypes 本身处理枚举结束的方式保持一致。
                 */
                enumerationBlock?(nil, stop)
            }
        }, failureBlock: { error in
            guard let error = error else { return }
            print("Asset group not found!error: \(error)")
        })
    }

    /**
     *  保存图片或视频到指定的相册
     *
     *  @warning 无论用户保存到哪个自行创建的相册，系统都会在“相机胶卷”相册中同时保存这个图片。
     *           原因请参考 QMUIAssetsManager 对象的保存图片和视频方法的注释。
     *           如果直接调用该接口保存图片或视频到“相机胶卷”中，并不会产生重复保存。
     */
    func writeImage(toSavedPhotosAlbum imageRef: CGImage, albumAssetsGroup: ALAssetsGroup, orientation: UIImageOrientation, completionBlock: @escaping ALAssetsLibraryWriteImageCompletionBlock) {
        // 调用系统的添加照片的接口，把图片保存到相机胶卷，从而生成一个图片的 ALAsset

        writeImage(toSavedPhotosAlbum: imageRef, orientation: orientation.assetOrientation) { assetURL, error in
            if let error = error {
                completionBlock(assetURL, error)
            } else {
                // 把获取到的 ALAsset 添加到用户指定的相册中
                self.add(assetURL!, albumAssetsGroup: albumAssetsGroup, completionBlock: { error in
                    completionBlock(assetURL, error)
                })
            }
        }
    }

    func writeVideoAtPath(toSavedPhotosAlbum videoPathURL: URL, albumAssetsGroup: ALAssetsGroup, completionBlock: @escaping ALAssetsLibraryWriteImageCompletionBlock) {
        // 调用系统的添加照片的接口，把图片保存到相机胶卷，从而生成一个图片的 ALAsset
        writeVideoAtPath(toSavedPhotosAlbum: videoPathURL) { assetURL, error in
            if let error = error {
                completionBlock(assetURL, error)
            } else {
                // 把获取到的 ALAsset 添加到用户指定的相册中
                self.add(assetURL!, albumAssetsGroup: albumAssetsGroup, completionBlock: { error in
                    completionBlock(assetURL, error)
                })
            }
        }
    }

    private func add(_ assetURL: URL, albumAssetsGroup: ALAssetsGroup, completionBlock: @escaping ALAssetsLibraryAccessFailureBlock) {
        asset(for: assetURL, resultBlock: { asset in
            albumAssetsGroup.add(asset)
            completionBlock(nil)
        }, failureBlock: { error in
            completionBlock(error)
        })
    }
}
