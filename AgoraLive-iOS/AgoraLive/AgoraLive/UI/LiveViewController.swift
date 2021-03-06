//
//  LiveViewController.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/4/10.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay
import MJRefresh

protocol LiveViewController: ShowAlertProtocol where Self: MaskViewController {
    var bag: DisposeBag {get set}
    var tintColor: UIColor {get set}
    
    var chatInputView: ChatInputView {get set}
    
    // ViewController
    var userListVC: UserListViewController? {get set}
    var giftAudienceVC: GiftAudienceViewController? {get set}
    var chatVC: ChatViewController? {get set}
    var bottomToolsVC: BottomToolsViewController? {get set}
    var beautyVC: BeautySettingsViewController? {get set}
    var musicVC: MusicViewController? {get set}
    var dataVC: RealDataViewController? {get set}
    var extensionVC: ExtensionViewController? {get set}
    var mediaSettingsNavi: UIViewController? {get set}
    var giftVC: GiftViewController? {get set}
    
    // View
    var personCountView: IconTextView! {get set}
    
    // View Model
    var audienceListVM: LiveRoomAudienceList {get set}
    var musicVM: MusicVM {get set}
    var chatVM: ChatVM {get set}
    var giftVM: GiftVM {get set}
    var deviceVM: MediaDeviceVM {get set}
    var playerVM: PlayerVM {get set}
}

// MARK: VM
extension LiveViewController {
    // MARK: - Audience
    func audience() {
        personCountView.backgroundColor = tintColor
        personCountView.offsetLeftX = -4.0
        personCountView.offsetRightX = 4.0
        personCountView.imageView.image = UIImage(named: "icon-audience")
        personCountView.label.textColor = UIColor.white
        personCountView.label.font = UIFont.systemFont(ofSize: 10)
        
        personCountView.rx.controlEvent(.touchUpInside).subscribe(onNext: { [unowned self] in
            self.presentAllUserList()
        }).disposed(by: bag)
        
        audienceListVM.giftList.subscribe(onNext: { [unowned self] (list) in
            self.giftAudienceVC?.list = list
        }).disposed(by: bag)
        
        audienceListVM.total.subscribe(onNext: { [unowned self] (total) in
            self.personCountView.label.text = "\(total)"
        }).disposed(by: bag)
        
        audienceListVM.list.subscribe(onNext: {[unowned self] (list) in
            self.personCountView.label.text = "\(list.count)"
        }).disposed(by: bag)
        
        audienceListVM.join.subscribe(onNext: { [unowned self] (list) in
            let chats = list.map { (user) -> Chat in
                let chat = Chat(name: user.info.name,
                                text: " \(NSLocalizedString("Join_Live_Room"))")
                return chat
            }
            
            self.chatVM.newMessages(chats)
        }).disposed(by: bag)
        
        audienceListVM.left.subscribe(onNext: { [unowned self] (list) in
            let chats = list.map { (user) -> Chat in
                let chat = Chat(name: user.info.name,
                                text: " \(NSLocalizedString("Leave_Live_Room"))")
                return chat
            }
            
            self.chatVM.newMessages(chats)
        }).disposed(by: bag)
    }
    
    // MARK: - Chat List
    func chatList() {
        chatVM.list.subscribe(onNext: { [unowned self] (list) in
            self.chatVC?.list = list
        }).disposed(by: bag)
    }
    
    // MARK: - Gift
    func gift() {
        giftVM.received.subscribe(onNext: { [unowned self] (userGift) in
            let chat = Chat(name: userGift.userName,
                            text: " " + NSLocalizedString("Give_Owner_A_Gift"),
                            image: userGift.gift.image)
            self.chatVM.newMessages([chat])
            
            guard userGift.gift.hasGIF else {
                return
            }
            
            self.presentGIF(gift: userGift.gift)
        }).disposed(by: bag)
    }
    
    // MARK: - Music List
    func musicList() {
        musicVM.refetch()
        musicVM.isPlaying.subscribe(onNext: { [unowned self] (isPlaying) in
            self.bottomToolsVC?.musicButton.isSelected = isPlaying
        }).disposed(by: bag)
    }
}

// MARK: - View
extension LiveViewController {
    // MARK: - Bottom Tools
    func bottomTools(session: LiveSession, tintColor: UIColor = .black) {
        guard let perspective = session.role?.type else {
            fatalError()
        }
        
        bottomToolsVC?.tintColor = tintColor
        
        switch perspective {
        case .owner, .broadcaster:
            bottomToolsVC?.beautyButton.rx.tap.subscribe(onNext: { [unowned self] () in
                self.showMaskView(color: UIColor.clear) { [unowned self] in
                    self.hiddenMaskView()
                    if let beautyVC = self.beautyVC {
                        self.dismissChild(beautyVC, animated: true)
                        self.beautyVC = nil
                    }
                }
                self.presentBeautySettings()
            }).disposed(by: bag)
            
            bottomToolsVC?.musicButton.rx.tap.subscribe(onNext: { [unowned self] () in
                self.showMaskView(color: UIColor.clear) { [unowned self] in
                    self.hiddenMaskView()
                    if let musicVC = self.musicVC {
                        self.dismissChild(musicVC, animated: true)
                        self.musicVC = nil
                    }
                }
                self.presentMusicList()
            }).disposed(by: bag)
            
            bottomToolsVC?.extensionButton.rx.tap.subscribe(onNext: { [unowned self] in
                self.showMaskView(color: UIColor.clear) { [unowned self] in
                    self.hiddenMaskView()
                    if let extensionVC = self.extensionVC {
                        self.dismissChild(extensionVC, animated: true)
                        self.extensionVC = nil
                    }
                }
                self.presentExtensionFunctions()
            }).disposed(by: bag)
            
            if perspective == .broadcaster {
                bottomToolsVC?.giftButton.rx.tap.subscribe(onNext: { [unowned self] in
                    self.showMaskView(color: UIColor.clear) { [unowned self] in
                        self.hiddenMaskView()
                        if let giftVC = self.giftVC {
                            self.dismissChild(giftVC, animated: true)
                            self.giftVC = nil
                        }
                    }
                    self.presentGiftList()
                }).disposed(by: bag)
            }
        case .audience:
            bottomToolsVC?.giftButton.rx.tap.subscribe(onNext: { [unowned self] in
                self.showMaskView(color: UIColor.clear) { [unowned self] in
                    self.hiddenMaskView()
                    if let giftVC = self.giftVC {
                        self.dismissChild(giftVC, animated: true)
                        self.giftVC = nil
                    }
                }
                self.presentGiftList()
            }).disposed(by: bag)
            
            bottomToolsVC?.extensionButton.rx.tap.subscribe(onNext: { [unowned self] in
                self.showMaskView(color: UIColor.clear) { [unowned self] in
                    self.hiddenMaskView()
                    if let extensionVC = self.extensionVC {
                        self.dismissChild(extensionVC, animated: true)
                        self.extensionVC = nil
                    }
                }
                self.presentExtensionFunctions()
            }).disposed(by: bag)
        }
        
        bottomToolsVC?.closeButton.rx.tap.subscribe(onNext: { [unowned self] () in
            if self is PKBroadcastersViewController {
                return
            }
            
            self.showAlert(NSLocalizedString("Live_End"),
                           message: NSLocalizedString("Confirm_End_Live"),
                           action1: NSLocalizedString("Cancel"),
                           action2: NSLocalizedString("Confirm")) { [unowned self] (_) in
                            self.leave()
            }
        }).disposed(by: bag)
    }
    
    // MARK: - Chat Input
    func chatInput() {
        chatInputView.textView.rx.controlEvent([.editingDidEndOnExit])
            .asObservable()
            .subscribe(onNext: { [unowned self] in
                self.hiddenMaskView()
                if !self.chatInputView.isHidden {
                    self.view.endEditing(true)
                }
                self.view.endEditing(true)
                
                guard let session = ALCenter.shared().liveSession else {
                    return
                }
                
                guard let role = session.role else {
                    fatalError()
                }
                
                if let text = self.chatInputView.textView.text, text.count > 0 {
                    self.chatInputView.textView.text = nil
                    self.chatVM.sendMessage(text, local: role.info) { [weak self] (_) in
                         self?.showAlert(message: NSLocalizedString("Send_Chat_Message_Fail"))
                    }
                }
        }).disposed(by: bag)
        
        NotificationCenter.default.observerKeyboard { [weak self] (info: (endFrame: CGRect, duration: Double)) in
            guard let strongSelf = self else {
                return
            }
            
            let isShow = info.endFrame.minY < UIScreen.main.bounds.height ? true : false
            
            if isShow && strongSelf.chatInputView.isHidden {
                strongSelf.showMaskView(color: UIColor.clear) { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.hiddenMaskView()
                    if !strongSelf.chatInputView.isHidden {
                        strongSelf.view.endEditing(true)
                    }
                    strongSelf.view.endEditing(true)
                }
                
                strongSelf.view.addSubview(strongSelf.chatInputView)
                strongSelf.chatInputView.textView.becomeFirstResponder()
                strongSelf.chatInputView.showAbove(frame: info.endFrame,
                                             duration: info.duration) { (done) in
                    
                }
            } else if !strongSelf.chatInputView.isHidden {
                strongSelf.chatInputView.hidden(duration: info.duration) { [weak self] (done) in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.chatInputView.removeFromSuperview()
                }
            }
        }
    }
}

extension LiveViewController {
    // MARK: - User List
    func presentUserList(listType: UserListViewController.ShowType) {
        guard let session = ALCenter.shared().liveSession else {
            return
        }
        
        let listVC = UIStoryboard.initViewController(of: "UserListViewController",
                                                       class: UserListViewController.self)
        
        listVC.showType = listType
        self.userListVC = listVC
        
        listVC.view.cornerRadius(10)
        
        let presenetedHeight: CGFloat = UIScreen.main.heightOfSafeAreaTop + 526.0 + 50.0
        let y = UIScreen.main.bounds.height - presenetedHeight
        let presentedFrame = CGRect(x: 0,
                                    y: y,
                                    width: UIScreen.main.bounds.width,
                                    height: presenetedHeight)
        
        self.presentChild(listVC,
                          animated: true,
                          presentedFrame: presentedFrame)
        
        let isOnlyAudience = (listType == .allUser) ? false : true
        
        audienceListVM.refetch(roomId: session.roomId, onlyAudience: isOnlyAudience)
        
        audienceListVM.list.subscribe(onNext: { [unowned self] (list) in
            self.userListVC?.userList = list
        }).disposed(by: bag)
        
        let roomId = session.roomId
        
        // Invite VC
        listVC.tableView.mj_header = MJRefreshNormalHeader(refreshingBlock: { [unowned self, unowned listVC] in
            self.audienceListVM.refetch(roomId: roomId, onlyAudience: isOnlyAudience, success: {
                listVC.tableView.mj_header?.endRefreshing()
            }) { // fail
                listVC.tableView.mj_header?.endRefreshing()
            }
        })
        
        listVC.tableView.mj_footer = MJRefreshBackFooter(refreshingBlock: { [unowned self, unowned listVC] in
            self.audienceListVM.fetch(roomId: roomId, onlyAudience: isOnlyAudience, success: {
                listVC.tableView.mj_footer?.endRefreshing()
            }) { // fail
                listVC.tableView.mj_footer?.endRefreshing()
            }
        })
    }
    
    // MARK: - Beauty Settings
    func presentBeautySettings() {
        let beautyVC = UIStoryboard.initViewController(of: "BeautySettingsViewController",
                                                       class: BeautySettingsViewController.self)
        self.beautyVC = beautyVC
        
        beautyVC.view.cornerRadius(10)
        
        let presenetedHeight: CGFloat = 50 + (44 * 4) + UIScreen.main.heightOfSafeAreaBottom
        let y = UIScreen.main.bounds.height - presenetedHeight
        let presentedFrame = CGRect(x: 0,
                                    y: y,
                                    width: UIScreen.main.bounds.width,
                                    height: UIScreen.main.bounds.height)
        self.presentChild(beautyVC,
                          animated: true,
                          presentedFrame: presentedFrame)
        
        beautyVC.enhanceVM.publishWork.subscribe(onNext: { [unowned self] (work) in
            self.bottomToolsVC?.beautyButton.isSelected = work.boolValue
        }).disposed(by: bag)
    }
    
    // MARK: - Music List
    func presentMusicList() {
        let musicVC = UIStoryboard.initViewController(of: "MusicViewController",
                                                      class: MusicViewController.self)
        self.musicVC = musicVC
        
        musicVC.view.cornerRadius(10)
        
        let presenetedHeight: CGFloat = 526.0 + UIScreen.main.heightOfSafeAreaBottom
        let y = UIScreen.main.bounds.height - presenetedHeight
        let presentedFrame = CGRect(x: 0,
                                    y: y,
                                    width: UIScreen.main.bounds.width,
                                    height: UIScreen.main.bounds.height)
        self.presentChild(musicVC,
                          animated: true,
                          presentedFrame: presentedFrame)
        
        musicVC.tableView.dataSource = nil
        musicVC.tableView.delegate = nil
        musicVM.list?.bind(to: musicVC.tableView.rx.items(cellIdentifier: "MusicCell",
                                                          cellType: MusicCell.self)) { index, music, cell in
                                                            cell.tagImageView.image = music.isPlaying ? musicVC.playingImage : musicVC.pauseImage
                                                            cell.isPlaying = music.isPlaying
                                                            cell.nameLabel.text = music.name
                                                            cell.singerLabel.text = music.singer
        }.disposed(by: bag)
        
        musicVC.tableView.rx.itemSelected.asObservable().subscribe(onNext: { [unowned self] (index) in
            self.musicVM.listSelectedIndex = index.row
        }).disposed(by: bag)
    }
    
    // MARK: - ExtensionFunctions
    func presentExtensionFunctions() {
        guard let session = ALCenter.shared().liveSession else {
            return
        }
        
        guard let perspective = session.role?.type else {
            fatalError()
        }
        
        let extensionVC = UIStoryboard.initViewController(of: "ExtensionViewController",
                                                          class: ExtensionViewController.self)
        extensionVC.perspective = perspective
        self.extensionVC = extensionVC
        
        extensionVC.view.cornerRadius(10)
        
        var height: CGFloat
        switch perspective {
        case .owner, .broadcaster:
            height = 264.0
        case .audience:
            height = 171.0
        }
        
        let presenetedHeight: CGFloat = height + UIScreen.main.heightOfSafeAreaBottom
        let y = UIScreen.main.bounds.height - presenetedHeight
        let presentedFrame = CGRect(x: 0,
                                    y: y,
                                    width: UIScreen.main.bounds.width,
                                    height: UIScreen.main.bounds.height)
        self.presentChild(extensionVC,
                          animated: true,
                          presentedFrame: presentedFrame)
        
        extensionVC.dataButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.hiddenMaskView()
            if let extensionVC = self.extensionVC {
                self.dismissChild(extensionVC, animated: true)
                self.extensionVC = nil
            }
            
            self.presentRealData()
        }).disposed(by: bag)
        
        extensionVC.settingsButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.hiddenMaskView()
            if let extensionVC = self.extensionVC {
                self.dismissChild(extensionVC, animated: true)
                self.extensionVC = nil
            }
            
            self.showMaskView(color: UIColor.clear) { [unowned self] in
                self.hiddenMaskView()
                if let mediaNavi = self.mediaSettingsNavi {
                    self.dismissChild(mediaNavi, animated: true)
                    self.mediaSettingsNavi = nil
                }
            }
            
            self.presentMediaSettings()
        }).disposed(by: bag)
        
        extensionVC.switchCameraButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.deviceVM.switchCamera()
        }).disposed(by: bag)
        
        extensionVC.cameraButton.isSelected = !self.deviceVM.camera.boolValue
        
        extensionVC.cameraButton.rx.tap.subscribe(onNext: { [unowned extensionVC, unowned self] in
            extensionVC.cameraButton.isSelected.toggle()
            self.deviceVM.camera = extensionVC.cameraButton.isSelected ? .off : .on
            
            guard let session = ALCenter.shared().liveSession else {
                return
            }
            
            guard var role = session.role else {
                fatalError()
            }
            var status = role.status
            switch self.deviceVM.camera {
            case .on:
                status.insert(.camera)
            case .off:
                status.remove(.camera)
            }
            role.updateLocal(status: status, of: session.roomId)
        }).disposed(by: bag)
        
        extensionVC.micButton.isSelected = !self.deviceVM.mic.boolValue
        
        extensionVC.micButton.rx.tap.subscribe(onNext: { [unowned extensionVC, unowned self] in
            extensionVC.micButton.isSelected.toggle()
            self.deviceVM.mic = extensionVC.micButton.isSelected ? .off : .on
            
            guard let session = ALCenter.shared().liveSession else {
                return
            }
            
            guard var role = session.role else {
                fatalError()
            }
            
            var status = role.status
            switch self.deviceVM.mic {
            case .on:
                status.insert(.mic)
            case .off:
                status.remove(.mic)
            }
            
            role.updateLocal(status: status, of: session.roomId)
        }).disposed(by: bag)
        
        extensionVC.audioLoopButton.rx.tap.subscribe(onNext: { [unowned extensionVC, unowned self] in
            guard self.deviceVM.audioOutput.value.isSupportLoop else {
                self.showAlert(NSLocalizedString("Please_Input_Headset"))
                return
            }
            extensionVC.audioLoopButton.isSelected.toggle()
            self.deviceVM.audioLoop(extensionVC.audioLoopButton.isSelected ? .off : .on)
        }).disposed(by: bag)
    }
    
    //MARK: - Media Settings
    func presentMediaSettings() {
        guard let session = ALCenter.shared().liveSession else {
            return
        }
        
        let mediaSettingsNavi = UIStoryboard.initViewController(of: "MediaSettingsNavigation",
                                                                class: UINavigationController.self)
        
        let mediaSettingsVC = mediaSettingsNavi.children.first! as! MediaSettingsViewController
        self.mediaSettingsNavi = mediaSettingsNavi
        
        mediaSettingsVC.settings = BehaviorRelay(value: session.settings.media)
        mediaSettingsVC.settings?.subscribe(onNext: { (newMedia) in
            guard let session = ALCenter.shared().liveSession else {
                return
            }
            
            var newSettings = session.settings
            newSettings.media = newMedia
            session.settings = newSettings
            
            session.setupMediaSettings(newMedia)
        }).disposed(by: bag)
        
        mediaSettingsVC.view.cornerRadius(5)
        
        let presenetedHeight: CGFloat = 239 + UIScreen.main.heightOfSafeAreaBottom
        let y = UIScreen.main.bounds.height - presenetedHeight
        let presentedFrame = CGRect(x: 0,
                                    y: y,
                                    width: UIScreen.main.bounds.width,
                                    height: UIScreen.main.bounds.height)
        self.presentChild(mediaSettingsNavi,
                          animated: true,
                          presentedFrame: presentedFrame)
    }
    
    // MARK: - Real Data
    func presentRealData() {
        guard let session = ALCenter.shared().liveSession else {
            return
        }
        
        let dataVC = UIStoryboard.initViewController(of: "RealDataViewController",
                                                     class: RealDataViewController.self)
        self.dataVC = dataVC
        
        dataVC.view.cornerRadius(10)
        
        session.rtcChannelReport?.subscribe(onNext: { [weak dataVC] (info) in
            dataVC?.infoLabel.text = info.description()
        }).disposed(by: bag)
        
        let leftSpace: CGFloat = 15.0
        let y: CGFloat = UIScreen.main.heightOfSafeAreaTop + 157.0
        let width: CGFloat = UIScreen.main.bounds.width - (leftSpace * 2)
        let presentedFrame = CGRect(x: leftSpace, y: y, width: width, height: 125.0)
        
        self.presentChild(dataVC,
                          animated: true,
                          presentedFrame: presentedFrame)
        
        dataVC.closeButton.rx.tap.subscribe(onNext: { [unowned self] in
            if let dataVC = self.dataVC {
                self.dismissChild(dataVC, animated: true)
                self.extensionVC = nil
            }
        }).disposed(by: bag)
    }
    
    // MARK: - Gift List
    func presentGiftList() {
        let giftVC = UIStoryboard.initViewController(of: "GiftViewController",
                                                     class: GiftViewController.self)
        self.giftVC = giftVC
        
        giftVC.view.cornerRadius(10)
        
        let presenetedHeight: CGFloat = UIScreen.main.heightOfSafeAreaTop + 336.0
        let y = UIScreen.main.bounds.height - presenetedHeight
        let presentedFrame = CGRect(x: 0,
                                    y: y,
                                    width: UIScreen.main.bounds.width,
                                    height: presenetedHeight)
        
        self.presentChild(giftVC,
                          animated: true,
                          presentedFrame: presentedFrame)
        
        giftVC.selectGift.subscribe(onNext: { [unowned self] (gift) in
            guard let session = ALCenter.shared().liveSession else {
                return
            }
            
            self.hiddenMaskView()
            if let giftVC = self.giftVC {
                self.dismissChild(giftVC, animated: true)
                self.mediaSettingsNavi = nil
            }
            
            switch session.owner {
            case .otherUser(let remote):
                self.giftVM.present(gift: gift,
                                    to: remote.info,
                                    from: session.role!.info,
                                    of: session.roomId) {
                                        self.showAlert(message: NSLocalizedString("Present_Gift_Fail"))
                }
            case .localUser:
                fatalError()
            }
        }).disposed(by: bag)
    }
    
    // MARK: - GIF
    func presentGIF(gift: Gift) {
        let gifVC = UIStoryboard.initViewController(of: "GIFViewController",
                                                    class: GIFViewController.self)
        
        gifVC.view.cornerRadius(10)
        
        let presentedFrame = CGRect(x: 0,
                                    y: 0,
                                    width: UIScreen.main.bounds.width,
                                    height: UIScreen.main.bounds.height)
        
        self.presentChild(gifVC,
                          animated: false,
                          presentedFrame: presentedFrame)
        
        let gif = Bundle.main.url(forResource: gift.gifFileName, withExtension: "gif")
        let data = try! Data(contentsOf: gif!)
        
        gifVC.startAnimating(of: data, repeatCount: 1) { [unowned self, weak gifVC] in
            if let vc = gifVC {
                self.dismissChild(vc, animated: true)
            }
        }
    }
    
    func presentAllUserList() {
        self.showMaskView(color: .clear) { [unowned self] in
            self.hiddenMaskView()
            if let vc = self.userListVC {
                self.dismissChild(vc, animated: true)
                self.userListVC = nil
            }
        }
        
        self.presentUserList(listType: .allUser)
    }
}

extension LiveViewController {
    func leave() {
        ALCenter.shared().liveSession?.leave()
        ALCenter.shared().liveSession = nil
        self.navigationController?.popViewController(animated: true)
    }
}
