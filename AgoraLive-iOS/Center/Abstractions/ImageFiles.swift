//
//  ImageFiles.swift
//  CheckIt
//
//  Created by CavanSu on 2019/7/16.
//  Copyright © 2019 Agora. All rights reserved.
//

#if os(iOS)
import UIKit
#else
import Cocoa
#endif

class ImageFiles: NSObject {
    private lazy var headCaches = [String: AGEImage]() // URL: Image
    private lazy var isDownloading = [String]()
    private let folderName = "Images/"
    private let headFolder = "Heads/"
    
    private(set) lazy var originals: [UIImage] = {
        var list = [UIImage]()
        
        for i in 0..<12 {
            let index = String(format: "%02d", i + 1)
            let name = "pic\(index)"
            let image = UIImage(named: name)
            list.append(image!)
        }
        return list
    }()
    
    private(set) var rooms = [UIImage]()
    private(set) var heads = [UIImage]()
    
    var folderPath: String {
        return FilesGroup.cacheDirectory + folderName
    }
    
    let clipQueue = DispatchQueue(label: "ImageClipQueue")
    
    override init() {
        super.init()
        FilesGroup.check(folderPath: folderPath)
        headClip()
        roomClip()
    }
    
    func getRoom(index: Int) -> UIImage {
        guard index >= 0 && index < rooms.count else {
            fatalError()
        }
        
        return rooms[index]
    }
    
    func getHead(index: Int) -> UIImage {
        guard index >= 0 && index < heads.count else {
            fatalError()
        }
        
        return heads[index]
    }
    
    func getOrigin(index: Int) -> UIImage {
        guard index >= 0 && index < originals.count else {
            fatalError()
        }
        
        return originals[index]
    }
}

private extension ImageFiles {
    func headClip() {
        self.clipQueue.async { [unowned self] in
            var list = [UIImage]()
            for image in self.originals {
                let clip = UIImage(clipImage: image,
                                   borderWidth: 0,
                                   borderColor: nil)
                list.append(clip)
            }
            
            self.heads = list
        }
    }
    
    func roomClip() {
        self.clipQueue.async { [unowned self] in
            var list = [UIImage]()
            for image in self.originals {
                let clip = UIImage(clipImage: image,
                                   cornerRadius: 7,
                                   borderWidth: 0,
                                   borderColor: nil)
                list.append(clip)
            }
            
            self.rooms = list
        }
    }
}

private extension ImageFiles {
    func getHead(url: String, success: ((AGEImage) -> Void)? = nil, error: ErrorCompletion = nil) {
        // default head
        if url.contains("local") {
            if let success = success {
                success(AGEImage(named: "head-default")!)
            }
            return
        }
        
        // 1.caches
        if let head = headCaches[url] {
            if let success = success {
                success(head)
            }
            return
        }
        
        let queue = DispatchQueue.main
        queue.async { [unowned self] in
            
            // 2.local
            if let head = try? self.localHead(url: url) {
                self.headCaches[url] = head
                if let success = success {
                    DispatchQueue.main.sync {
                        success(head)
                    }
                }
                return
            }
            
            // check this image is downloading
            if let _ = self.isDownloading.first(where: {$0 == url}) {
                return
            }
            
            self.isDownloading.append(url)
            
            // 3.download
            self.download(url: url, success: { (image) in
                self.headCaches[url] = image
                self.isDownloading.removeAll(where: {$0 == url})
                try? self.save(image, name: url + ".png")
                if let success = success {
                    DispatchQueue.main.sync {
                        success(image)
                    }
                }
            }) { (mError) in
                self.isDownloading.removeAll(where: {$0 == url})
                if let error = error {
                    DispatchQueue.main.async {
                        error(mError)
                    }
                }
            }
        }
    }
    
    func removeHead(url: String) {
        headCaches.removeValue(forKey: url)
    }
    
    func localHead(url: String) throws -> AGEImage {
        let fullPath = folderPath + headFolder + "\(url).png"
        return try self.local(path: fullPath)
    }
}

private extension ImageFiles {
    func download(url: String, success: ((AGEImage) -> Void)? = nil, error: ErrorCompletion = nil) {
        let client = ALCenter.shared().centerProvideRequestHelper()
        let event = RequestEvent(name: "download-head")
        let task = RequestTask(event: event, type: .http(.get, url: url))
        
        let successCallback: DataExCompletion = { (data: Data) throws in
            let image = try UIImage.initWith(data: data)
            if let success = success {
                success(image)
            }
        }
        
        let retry: ErrorRetryCompletion = { (mError: AGEError) in
            if let error = error {
                error(mError)
            }
            return .resign
        }
        
        let response = AGEResponse.data(successCallback)
        
        client.request(task: task, success: response, failRetry: retry)
    }
    
    func local(path: String) throws -> AGEImage  {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let image = try AGEImage.initWith(data: data)
        return image
    }
    
    func save(_ image: AGEImage, name: String) throws {
        guard let data = image.data else {
            return
        }
        
        let fullPath = self.folderPath + "/" + name
        let url = URL(fileURLWithPath: fullPath)
        try data.write(to: url)
    }
}
