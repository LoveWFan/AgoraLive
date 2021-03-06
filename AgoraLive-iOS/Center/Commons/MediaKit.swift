//
//  MediaKit.swift
//  AGECenter
//
//  Created by CavanSu on 2019/6/23.
//  Copyright © 2019 Agora. All rights reserved.
//

import Foundation
import AgoraRtcKit

typealias AudioOutputRouting = AgoraAudioOutputRouting
typealias ChannelReport = StatisticsInfo
//typealias SpeakerReport =

class MediaKit: NSObject, AGELogBase {
    enum Speaker {
        case local, other(agoraUid: UInt)
    }
    
    enum Event {
        case channelStats(((ChannelReport) -> Void)?), activeSpeaker(((Speaker) -> Void)?)
    }
    
    static var rtcKit = AgoraRtcEngineKit.sharedEngine(withAppId: ALKeys.AgoraAppId,
                                                       delegate: nil)
    
    fileprivate let agoraKit = rtcKit
    fileprivate var channelProfile: AgoraChannelProfile = .liveBroadcasting
    
    private lazy var eventObservers = [NSObject: Event]()
    
    private(set) var channelReport: StatisticsInfo? {
        didSet {
            guard let channelReport = channelReport else {
                return
            }
            
            for (_, event) in eventObservers {
                switch event {
                case .channelStats(let callback):
                    if let tCallback = callback {
                        tCallback(channelReport)
                    }
                default:
                    continue
                }
            }
        }
    }
    
    private(set) var channelStatus: AGEChannelStatus = .out
    
    lazy var capture = Capture(parent: self)
    lazy var player = Player()
    lazy var enhancement = VideoEnhancement()
    
    var rtcVersion: String {
        return AgoraRtcEngineKit.getSdkVersion()
    }
    
    var consumer: AgoraVideoFrameConsumer?
    var logTube: LogTube
    
    init(log: LogTube) {
        self.logTube = log
        super.init()
        self.reinitRTC()
    }
    
    func reinitRTC() {
        MediaKit.rtcKit = AgoraRtcEngineKit.sharedEngine(withAppId: ALKeys.AgoraAppId,
                                                         delegate: self)
        MediaKit.rtcKit.delegate = self
        MediaKit.rtcKit.alMode()
        MediaKit.rtcKit.setVideoSource(self)
        let files = ALCenter.shared().centerProvideFilesGroup()
        let path = files.logs.folderPath + "/rtc.log"
        MediaKit.rtcKit.setLogFile(path)
    }
    
    func join(channel: String, token: String? = nil, streamId: Int, parameters: [String]? = nil, success: Completion = nil) {
        if let parameters = parameters {
            for item in parameters {
                agoraKit.setParameters(item)
            }
        }
        
        agoraKit.join(channel: channel, token: token, streamId: streamId) { [unowned self] in
            self.channelStatus = .ing
            if let success = success {
                success()
            }
        }
    }
    
    func leaveChannel() {
        self.channelStatus = .out
        agoraKit.leaveChannel(nil)
    }
    
    func setupVideo(resolution: CGSize, frameRate: AgoraVideoFrameRate, bitRate: Int) {
        log(info: "setup video",
            extra: "resolution: \(resolution.debugDescription), frameRate: \(frameRate.rawValue), bitRate: \(bitRate)")
        agoraKit.setupVideo(resolution: resolution, frameRate: frameRate, bitRate: bitRate)
    }
    
    func addEvent(_ event: Event, observer: NSObject) {
        eventObservers[observer] = event
    }
    
    func removeObserver(_ observer: NSObject) {
        eventObservers.removeValue(forKey: observer)
    }
    
    func mediaStreamSend(_ action: AGESwitch) {
        agoraKit.muteLocalAudioStream(action.boolValue)
        agoraKit.muteLocalVideoStream(action.boolValue)
    }
    
    func startRelayingMediaStreamOf(currentChannel: String, currentSourceToken: String, to otherChannel: String, with otherChannelToken: String, otherChannelUid: UInt) {
        let configuration = AgoraChannelMediaRelayConfiguration()
        let sourceInfo = AgoraChannelMediaRelayInfo(token: currentSourceToken)
        sourceInfo.channelName = currentChannel
        sourceInfo.uid = 0
        configuration.sourceInfo = sourceInfo
        
        let destinationInfo = AgoraChannelMediaRelayInfo(token: otherChannelToken)
        destinationInfo.uid = otherChannelUid
        destinationInfo.channelName = otherChannel
        configuration.setDestinationInfo(destinationInfo, forChannelName: otherChannel)
        agoraKit.startChannelMediaRelay(configuration)
    }
    
    func stopRelayingMediaStream() {
        agoraKit.stopChannelMediaRelay()
    }
}

extension MediaKit {
    func checkChannelProfile() {
        guard channelProfile == .liveBroadcasting else {
            return
        }
        
        if capture.video == .off,
            capture.audio == .off {
            agoraKit.setClientRole(.audience)
        } else {
            agoraKit.setClientRole(.broadcaster)
        }
    }
}

extension MediaKit: AgoraVideoSourceProtocol {
    func shouldInitialize() -> Bool {
        return true
    }
    
    func shouldStart() {
        
    }
    
    func shouldStop() {
        
    }
    
    func shouldDispose() {
        
    }
    
    func bufferType() -> AgoraVideoBufferType {
        return .pixelBuffer
    }
}

extension MediaKit: AGESingleCameraDelegate {
    func camera(_ camera: AGESingleCamera, position: Position, didOutput sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .init(rawValue: 0))
        
        let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if enhancement.work == .on {
            FUManager.share()?.renderItems(to: pixelBuffer)
        }
        
        self.consumer?.consumePixelBuffer(pixelBuffer,
                                          withTimestamp: timeStamp,
                                          rotation: .rotationNone)
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .init(rawValue: 0))
    }
}

extension MediaKit: AgoraRtcEngineDelegate {
    func rtcEngineLocalAudioMixingDidFinish(_ engine: AgoraRtcEngineKit) {
        if let block = self.player.mixFileAudioFinish {
            block()
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        log(error: AGEError(type: .rtc("did occur error"), code: errorCode.rawValue))
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didAudioRouteChanged routing: AgoraAudioOutputRouting) {
        player.audioRoute = routing
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, reportRtcStats stats: AgoraChannelStats) {
        let info = StatisticsInfo(type: .local(StatisticsInfo.LocalInfo(stats: stats)))
        channelReport = info
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didReceive event: AgoraChannelMediaRelayEvent) {
        
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, channelMediaRelayStateDidChange state: AgoraChannelMediaRelayState, error: AgoraChannelMediaRelayError) {
        if error != .none {
            log(error: AGEError(type: .rtc("channel media relay error"), code: error.rawValue))
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, reportAudioVolumeIndicationOfSpeakers speakers: [AgoraRtcAudioVolumeInfo], totalVolume: Int) {
        for user in speakers {
            let speakerUid = user.uid
            for (_, event) in eventObservers {
                switch event {
                case .activeSpeaker(let callback):
                    if let tCallback = callback {
                        if speakerUid == 0 {
                            tCallback(Speaker.local)
                        } else {
                            tCallback(Speaker.other(agoraUid: speakerUid))
                        }
                    }
                default:
                    continue
                }
            }
        }
    }
}

// MARK: Log
private extension MediaKit {
    func log(info: String, extra: String? = nil, funcName: String = #function) {
        let className = MediaKit.self
        logOutputInfo(info, extra: extra, className: className, funcName: funcName)
    }
    
    func log(warning: String, extra: String? = nil, funcName: String = #function) {
        let className = MediaKit.self
        logOutputWarning(warning, extra: extra, className: className, funcName: funcName)
    }
    
    func log(error: Error, extra: String? = nil, funcName: String = #function) {
        let className = MediaKit.self
        logOutputError(error, extra: extra, className: className, funcName: funcName)
    }
}
