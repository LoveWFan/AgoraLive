//
//  LiveListVM.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/2/21.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay

struct RoomBrief {
    var name: String
    var roomId: String
    var imageURL: String
    var personCount: Int
    var imageIndex: Int
    var ownerAgoraUid: Int
    
    init(name: String = "", roomId: String, imageURL: String = "", personCount: Int = 0, ownerAgoraUid: Int = 0) {
        self.name = name
        self.roomId = roomId
        self.imageURL = imageURL
        self.personCount = personCount
        self.imageIndex = Int(Int64(self.roomId)! % 12)
        self.ownerAgoraUid = ownerAgoraUid
    }
    
    init(dic: StringAnyDic) throws {
        self.name = try dic.getStringValue(of: "roomName")
        self.roomId = try dic.getStringValue(of: "roomId")
        self.imageURL = try dic.getStringValue(of: "thumbnail")
        self.personCount = try dic.getIntValue(of: "currentUsers")
        self.ownerAgoraUid = try dic.getIntValue(of: "ownerUid")
        #warning("next version")
        self.imageIndex = Int(Int64(self.roomId)! % 12)
    }
}

fileprivate extension Array where Element == RoomBrief {
    init(dicList: [StringAnyDic]) throws {
        var array = [RoomBrief]()
        for item in dicList {
            let room = try RoomBrief(dic: item)
            array.append(room)
        }
        self = array
    }
}

class LiveListVM: NSObject {
    fileprivate var multiBroadcastersList = [RoomBrief]() {
        didSet {
            switch presentingType {
            case .multiBroadcasters:
                presentingList.accept(multiBroadcastersList)
            default:
                break
            }
        }
    }
    
    fileprivate var singleBroadcasterList = [RoomBrief](){
        didSet {
            switch presentingType {
            case .singleBroadcaster:
                presentingList.accept(singleBroadcasterList)
            default:
                break
            }
        }
    }
    
    fileprivate var pkBroadcastersList = [RoomBrief]() {
        didSet {
            switch presentingType {
            case .pkBroadcasters:
                presentingList.accept(pkBroadcastersList)
            default:
                break
            }
        }
    }
    
    var presentingType = LiveType.multiBroadcasters {
        didSet {
            switch presentingType {
            case .multiBroadcasters:
                presentingList.accept(multiBroadcastersList)
            case .singleBroadcaster:
                presentingList.accept(singleBroadcasterList)
            case .pkBroadcasters:
                presentingList.accept(pkBroadcastersList)
            }
        }
    }
    
    var presentingList = BehaviorRelay(value: [RoomBrief]())
}

extension LiveListVM {
    func fetch(count: Int = 10, success: Completion = nil, fail: Completion = nil) {
        guard let lastRoom = self.presentingList.value.last else {
            return
        }
        
        let client = ALCenter.shared().centerProvideRequestHelper()
        let requestListType = presentingType
        let parameters: StringAnyDic = ["nextId": lastRoom.roomId,
                                        "count": count,
                                        "type": requestListType.rawValue]
        
        let url = URLGroup.roomPage
        let event = RequestEvent(name: "room-page")
        let task = RequestTask(event: event,
                               type: .http(.get, url: url),
                               timeout: .low,
                               header: ["token": ALKeys.ALUserToken],
                               parameters: parameters)
        
        let successCallback: DicEXCompletion = { [unowned self] (json: ([String: Any])) in
            let object = try json.getDataObject()
            let jsonList = try object.getValue(of: "list", type: [StringAnyDic].self)
            let list = try [RoomBrief](dicList: jsonList)
            
            switch requestListType {
            case .multiBroadcasters:
                self.multiBroadcastersList.append(contentsOf: list)
            case .singleBroadcaster:
                self.singleBroadcasterList.append(contentsOf: list)
            case .pkBroadcasters:
                self.pkBroadcastersList.append(contentsOf: list)
            }
            
            if let success = success {
                success()
            }
        }
        let response = AGEResponse.json(successCallback)
        
        let retry: ErrorRetryCompletion = { (error: AGEError) -> RetryOptions in
            if let fail = fail {
                fail()
            }
            return .resign
        }
        
        client.request(task: task, success: response, failRetry: retry)
    }
    
    func refetch(success: Completion = nil, fail: Completion = nil) {
        let client = ALCenter.shared().centerProvideRequestHelper()
        let requestListType = presentingType
        let currentCount = presentingList.value.count == 0 ? 10 : presentingList.value.count
        let parameters: StringAnyDic = ["count": currentCount,
                                        "type": requestListType.rawValue]
        
        let url = URLGroup.roomPage
        let event = RequestEvent(name: "room-page-refetch")
        let task = RequestTask(event: event,
                               type: .http(.get, url: url),
                               timeout: .low,
                               header: ["token": ALKeys.ALUserToken],
                               parameters: parameters)
        
        let successCallback: DicEXCompletion = { [unowned self] (json: ([String: Any])) in
            try json.getCodeCheck()
            let object = try json.getDataObject()
            let jsonList = try object.getValue(of: "list", type: [StringAnyDic].self)
            let list = try [RoomBrief](dicList: jsonList)
            
            switch requestListType {
            case .multiBroadcasters:
                self.multiBroadcastersList = list
            case .singleBroadcaster:
                self.singleBroadcasterList = list
            case .pkBroadcasters:
                self.pkBroadcastersList = list
            }
            
            if let success = success {
                success()
            }
        }
        let response = AGEResponse.json(successCallback)
        
        let retry: ErrorRetryCompletion = { (error: AGEError) -> RetryOptions in
            if let fail = fail {
                fail()
            }
            return .resign
        }
        
        client.request(task: task, success: response, failRetry: retry)
    }
}
