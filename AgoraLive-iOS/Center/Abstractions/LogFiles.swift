//
//  LogFiles.swift
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

class LogFiles: NSObject {
    private let fileName: String = {
        let date = Date.currentTimeString(range: [.month, .day, .hour, .minute, .second])
        let name = "app" + date + ".log"
        return name
    }()
    
    private let folderName = "Log"
    private let maxAppLogsCount: Int = 5
    
    var folderPath: String {
        return FilesGroup.cacheDirectory + folderName
    }
    
    override init() {
        super.init()
        FilesGroup.check(folderPath: folderPath)
        checkEarliestFile()
        createFile()
    }
    
    func upload(success: Completion, fail: ErrorCompletion) {
        do {
            try privateUpload(success: success, fail: fail)
        } catch let error as AGEError {
            if let fail = fail {
                fail(error)
            }
        } catch {
            if let fail = fail {
                fail(AGEError.fail(error.localizedDescription))
            }
        }
    }
}

private extension LogFiles {
    func privateUpload(success: Completion, fail: ErrorCompletion) throws {
        let zipPath = try ZipTool.work(destination: folderPath, to: FilesGroup.cacheDirectory)
        let url = URL(fileURLWithPath: zipPath)
        let _ = try Data(contentsOf: url)
        
        let _ = ALCenter.shared().centerProvideRequestHelper()
    }
    
    func checkEarliestFile() {
        let manager = FileManager.default
        
        let direcEnumerator = manager.enumerator(atPath: folderPath)
        var logsList = [String]()
        
        while let file = direcEnumerator?.nextObject() as? String {
            if !file.contains("app") {
                continue
            }
            
            let fullPath = "\(folderPath)/\(file)"
            logsList.append(fullPath)
        }
        
        guard logsList.count >= maxAppLogsCount else {
            return
        }
        
        var earliest = 0
        var lastFileCreatedDate: Date?
        
        for (index, item)  in logsList.enumerated() {
            guard let fileDic = try? manager.attributesOfItem(atPath: item) else {
                continue
            }
            
            guard let fileDate = fileDic[FileAttributeKey.creationDate] as? Date else {
                continue
            }
            
            if let lastDate = lastFileCreatedDate,
                lastDate.compare(fileDate) == ComparisonResult.orderedDescending {
                lastFileCreatedDate = fileDate
                earliest = index
            } else {
                lastFileCreatedDate = fileDate
            }
        }
        
        guard let _ = lastFileCreatedDate else {
            return
        }
        
        let removeFile = logsList[earliest]
        try? manager.removeItem(atPath: removeFile)
    }
    
    func createFile() {
        let filePath = folderPath + "/" + fileName
        LCLLogFile.setEscapesLineFeeds(true)
        LCLLogFile.setPath(filePath)
    }
}
