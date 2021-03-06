//
//  MultiBroadcastersViewController.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/3/23.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay
import MJRefresh

class MultiBroadcastersViewController: MaskViewController, LiveViewController {
    @IBOutlet weak var ownerRenderView: LabelShadowRender!
    @IBOutlet weak var roomLabel: UILabel!
    @IBOutlet weak var roomNameLabel: UILabel!
    
    private weak var seatVC: LiveSeatViewController?
    
    var seatVM: LiveSeatVM!
    
    // LiveViewController
    var tintColor = UIColor(red: 0,
                            green: 0,
                            blue: 0,
                            alpha: 0.4)
    
    var bag = DisposeBag()
    
    // ViewController
    var userListVC: UserListViewController?
    var giftAudienceVC: GiftAudienceViewController?
    var chatVC: ChatViewController?
    var bottomToolsVC: BottomToolsViewController?
    var beautyVC: BeautySettingsViewController?
    var musicVC: MusicViewController?
    var dataVC: RealDataViewController?
    var extensionVC: ExtensionViewController?
    var mediaSettingsNavi: UIViewController?
    var giftVC: GiftViewController?
    var gifVC: GIFViewController?
    
    // View
    @IBOutlet weak var personCountView: IconTextView!
    
    internal lazy var chatInputView: ChatInputView = {
        let chatHeight: CGFloat = 50.0
        let frame = CGRect(x: 0,
                           y: UIScreen.main.bounds.height,
                           width: UIScreen.main.bounds.width,
                           height: chatHeight)
        let view = ChatInputView(frame: frame)
        view.isHidden = true
        return view
    }()
    
    // ViewModel
    var audienceListVM = LiveRoomAudienceList()
    var musicVM = MusicVM()
    var chatVM = ChatVM()
    var giftVM = GiftVM()
    var deviceVM = MediaDeviceVM()
    var playerVM = PlayerVM()
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let image = UIImage(named: "live-bg")
        self.view.layer.contents = image?.cgImage

        guard let session = ALCenter.shared().liveSession else {
            fatalError()
        }
        
        liveRoom(session: session)
        liveRole(session: session)
        audience()
        liveSeat(roomId: session.roomId)
        chatList()
        gift()

        bottomTools(session: session, tintColor: tintColor)
        chatInput()
        musicList()
        activeSpeaker()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier else {
            return
        }
        
        switch identifier {
        case "LiveSeatViewController":
            guard let type = ALCenter.shared().liveSession?.role?.type else {
                fatalError()
            }

            let vc = segue.destination as! LiveSeatViewController
            vc.perspective = type
            self.seatVC = vc
        case "GiftAudienceViewController":
            let vc = segue.destination as! GiftAudienceViewController
            self.giftAudienceVC = vc
        case "BottomToolsViewController":
            guard let type = ALCenter.shared().liveSession?.role?.type else {
                fatalError()
            }
            
            let vc = segue.destination as! BottomToolsViewController
            vc.perspective = type
            self.bottomToolsVC = vc
        case "ChatViewController":
            let vc = segue.destination as! ChatViewController
            vc.cellColor = tintColor
            self.chatVC = vc
        default:
            break
        }
    }
    
    func activeSpeaker() {
        playerVM.activeSpeaker.subscribe(onNext: { [weak self] (speaker) in
            guard let strongSelf = self,
                let session = ALCenter.shared().liveSession else {
                return
            }
            
            switch (speaker, session.owner) {
            case (.local, .localUser):
                strongSelf.ownerRenderView.startSpeakerAnimating()
            case (.other(agoraUid: let uid), .otherUser(let user)):
                if uid == user.agoraUserId {
                    strongSelf.ownerRenderView.startSpeakerAnimating()
                } else {
                    fallthrough
                }
            default:
                strongSelf.seatVC?.activeSpeaker(speaker)
            }
        }).disposed(by: bag)
    }
}

//MARK: - Specail MultiBroadcasters
extension MultiBroadcastersViewController {
    //MARK: - Live Seat
    func liveSeat(roomId: String) {
        // Media
        seatVC?.userRender.subscribe(onNext: { [unowned self] (viewUser) in
            guard let session = ALCenter.shared().liveSession else {
                return
            }

            guard let local = session.role else {
                fatalError()
            }

            if local.agoraUserId == viewUser.1.agoraUserId {
                self.playerVM.renderLocalVideoStream(id: viewUser.1.agoraUserId,
                                                     view: viewUser.0)
            } else {
                self.playerVM.renderRemoteVideoStream(id: viewUser.1.agoraUserId,
                                                      view: viewUser.0)
            }
        }).disposed(by: bag)

        seatVC?.userAudioSilence.subscribe(onNext: { [unowned self] (user) in
            guard let session = ALCenter.shared().liveSession else {
                return
            }

            guard let local = session.role else {
                fatalError()
            }

            guard local.agoraUserId == user.agoraUserId else {
               return
            }

            self.deviceVM.mic = user.status.contains(.mic) ? .on : .off
        }).disposed(by: bag)

        // Live Seat List
        seatVM.list.subscribe(onNext: { [unowned self] (list) in
            guard let session = ALCenter.shared().liveSession else {
                fatalError()
            }

            // Local user starts / stops broadcasting
            self.localUserRoleChangeWith(seatList: list)
            self.seatVC!.updateSeats(list, of: session)
        }).disposed(by: bag)

        // Live Seat Command
        seatVC?.commandFire.subscribe(onNext: { [unowned self] (seatCommand) in
            guard seatCommand.command != .none else {
                return
            }

            guard let session = ALCenter.shared().liveSession else {
                fatalError()
            }

            switch seatCommand.command {
            // Owner
            case .invite:
                self.showMaskView(color: UIColor.clear) {
                    self.hiddenMaskView()
                    if let vc = self.userListVC {
                        self.dismissChild(vc, animated: true)
                        self.userListVC = nil
                    }
                }
                self.presentInviteList(seat: seatCommand.seat)
            case .close, .ban, .unban, .forceToAudience, .release:
                guard session.owner.isLocal,
                    let role = session.role as? LiveOwner else {
                    fatalError()
                }

                let handler: ((UIAlertAction) -> Void)? = {[weak self] (_) in
                    self?.seatVM.localOwner(role,
                                           command: seatCommand.command,
                                           on: seatCommand.seat,
                                           of: roomId) { [weak self] (_) in
                                            self?.showAlert(NSLocalizedString("Seat_Command_Fail"))
                    }
                }

                let message = self.alertMessageOfSeatCommand(seatCommand.command,
                                                             with: seatCommand.seat.user?.info.name)

                self.showAlert(seatCommand.command.description,
                               message: message,
                               action1: NSLocalizedString("Cancel"),
                               action2: NSLocalizedString("Confirm"),
                               handler2: handler)
            // Broadcaster
            case .endBroadcasting:
                guard let role = session.role as? MultiBroadBroadcaster else {
                    fatalError()
                }

                self.showAlert(seatCommand.command.description,
                               message: NSLocalizedString("Confirm_End_Broadcasting"),
                               action1: NSLocalizedString("Cancel"),
                               action2: NSLocalizedString("Confirm")) { [unowned self] (_) in
                                self.seatVM.localBroadcaster(role, endBroadcastingOn: seatCommand.seat, of: roomId)
                }
            // Audience
            case .applyForBroadcasting:
                let handler: ((UIAlertAction) -> Void)? =  {[unowned self] (_) in
                    switch session.owner {
                    case .otherUser(let remote):
                        guard let role = session.role as? LiveAudience else {
                            fatalError()
                        }

                        self.seatVM.localAudience(role,
                                                  applyForBroadcastingToOwner: remote.agoraUserId,
                                                  seat: seatCommand.seat) {[unowned self] (_) in
                                                    self.showAlert(NSLocalizedString("Apply_For_Broadcasting_Fail"))
                        }
                    case .localUser: fatalError()
                    }
                }

                self.showAlert(NSLocalizedString("Apply_For_Broadcasting"),
                               action1: NSLocalizedString("Cancel"),
                               action2: NSLocalizedString("Confirm"),
                               handler2: handler)
            case .none:
                break
            }
        }).disposed(by: bag)
    }
    
    //MARK: - User List
    func presentInviteList(seat: LiveSeat) {
        guard let session = ALCenter.shared().liveSession else {
            return
        }
        
        presentUserList(listType: .broadcasting)
        
        let roomId = session.roomId
        
        self.userListVC?.selectedInviteAudience.subscribe(onNext: { [unowned self] (user) in
            guard let session = ALCenter.shared().liveSession else {
                return
            }
            
            self.hiddenMaskView()
            if let vc = self.userListVC {
                self.dismissChild(vc, animated: true)
                self.userListVC = nil
            }
            
            guard let role = session.role as? LiveOwner else {
                fatalError()
            }
            
            self.seatVM.localOwner(role,
                                   command: .invite,
                                   on: seat,
                                   with: user,
                                   of: roomId) {[unowned self] (_) in
                                    self.showAlert(message: NSLocalizedString("Invite_Broadcasting_Fail"))
            }
        }).disposed(by: bag)
    }
}

private extension MultiBroadcastersViewController {
    // MARK: - Live Room
    func liveRoom(session: LiveSession) {
        ownerRenderView.cornerRadius(5)
        ownerRenderView.layer.masksToBounds = true
        ownerRenderView.imageView.isHidden = true
        ownerRenderView.backgroundColor = tintColor
        
        let owner = session.owner
        
        switch owner {
        case .localUser:
            guard let localRole = session.role else {
                fatalError()
            }
            let images = ALCenter.shared().centerProvideImagesHelper()
            
            ownerRenderView.imageView.image = images.getOrigin(index: localRole.info.imageIndex)
            ownerRenderView.label.text = localRole.info.name
            playerVM.renderLocalVideoStream(id: localRole.agoraUserId,
                                            view: self.ownerRenderView.renderView)
            deviceVM.camera = .on
            deviceVM.mic = .on
        case .otherUser(let remote):
            let images = ALCenter.shared().centerProvideImagesHelper()
            ownerRenderView.imageView.image = images.getOrigin(index: remote.info.imageIndex)
            ownerRenderView.label.text  = remote.info.name
            playerVM.renderRemoteVideoStream(id: remote.agoraUserId,
                                                    view: self.ownerRenderView.renderView)
            deviceVM.camera = .off
            deviceVM.mic = .off
        }
        
        self.roomLabel.text = NSLocalizedString("Live_Room") + ": "
        self.roomNameLabel.text = session.settings.title
        
        session.end.subscribe(onNext: { [unowned self] (_) in
            guard !owner.isLocal else {
                return
            }
            
            self.showAlert(NSLocalizedString("Live_End")) { [unowned self] (_) in
                self.leave()
            }
        }).disposed(by: bag)
    }
    
    func liveRole(session: LiveSession) {
        guard let localRole = session.role else {
            fatalError()
        }
        let roomId = session.roomId
        
        // Owner
        switch localRole.type {
        case .owner:
            seatVM.receivedRejectInviteBroadcasting.subscribe(onNext: { [unowned self] (userName) in
                self.showAlert(message: userName + NSLocalizedString("Reject"))
            }).disposed(by: bag)
            
            seatVM.receivedBroadcasting.subscribe(onNext: { [unowned self] (peerInfo) in
                self.showAlert(message: "\"\(peerInfo.userName)\" " + NSLocalizedString("Apply_For_Broadcasting"),
                               action1: NSLocalizedString("Reject"),
                               action2: NSLocalizedString("Confirm"), handler1: { [unowned session] (_) in
                                let role = session.role as! LiveOwner

                                self.seatVM.localOwner(role, rejectBroadcastingAudience: peerInfo.agoraUserId)
                }) {[unowned self] (_) in
                    self.seatVM.localOwnerAcceptBroadcasting(audience: peerInfo.userId,
                                                             seatIndex: peerInfo.seatIndex!,
                                                             roomId: roomId)
                }
            }).disposed(by: bag)
        case .broadcaster:
            break
        case .audience:
            let audience = localRole as! LiveAudience
            
            seatVM.receivedInvite.subscribe(onNext: {[unowned self] (peerInfo) in
                self.showAlert(NSLocalizedString("Invite_A_Broadcast"),
                               action1: NSLocalizedString("Reject"),
                               action2: NSLocalizedString("Confirm"),
                               handler1: {[unowned self] (_) in
                                
                                self.seatVM.localAudience(audience, rejectInvitingFrom: peerInfo.agoraUserId)
                }) {[unowned self] (_) in
                    self.seatVM.localAudience(audience, acceptInvitingOn: peerInfo.seatIndex!, roomId: roomId)
                }
            }).disposed(by: bag)
            
            seatVM.receivedRejectBroadcasting.subscribe(onNext: {[unowned self] (userName) in
                self.showAlert(message: NSLocalizedString("Owner_Reject_Broadcasting_Application"))
            }).disposed(by: bag)
        }
        
        session.ownerInfoUpdate.subscribe(onNext: {[unowned self] (owner) in
            self.ownerRenderView.imageView.isHidden = owner.status.contains(.camera)
            self.ownerRenderView.audioSilenceTag.isHidden = owner.status.contains(.mic)
        }).disposed(by: bag)
    }
}

private extension MultiBroadcastersViewController {
    func localUserRoleChangeWith(seatList: [LiveSeat]) {
        guard let session = ALCenter.shared().liveSession else {
            fatalError()
        }
        
        guard let role = session.role else {
            fatalError()
        }
        
        switch role.type {
        case .broadcaster:
            var isBroadcaster = false
            for seat in seatList where seat.state == .normal {
                guard let user = seat.user else {
                    fatalError()
                }
                
                if user.info.userId == role.info.userId {
                    isBroadcaster = true
                    break
                }
            }
            
            guard !isBroadcaster else {
                return
            }
            
            self.chatVM.sendMessage(NSLocalizedString("Stopped_Hosting"), local: role.info)
            let role = session.broadcasterToAudience()
            self.seatVC?.perspective = role.type
        case .audience:
            var isBroadcaster = false
            for seat in seatList where seat.state == .normal {
                guard let user = seat.user else {
                    fatalError()
                }
                
                if user.info.userId == role.info.userId {
                    isBroadcaster = true
                    break
                }
            }
            
            guard isBroadcaster else {
                return
            }
            
            self.chatVM.sendMessage(NSLocalizedString("Became_A_Host"), local: role.info)
            let role = session.audienceToBroadcaster()
            self.seatVC?.perspective = role.type
        case .owner:
            break
        }
    }
    
    func alertMessageOfSeatCommand(_ command: SeatCommand, with userName: String?) -> String {
        switch command {
        case .ban:
            return "禁止\"\(userName!)\"发言?"
        case .unban:
            return "解除\"\(userName!)\"禁言?"
        case .forceToAudience:
            if DeviceAssistant.Language.isChinese {
                return "确定\"\(userName!)\"下麦?"
            } else {
                return "Stop \"\(userName!)\" hosting"
            }
        case .close:
            return "将关闭该麦位，如果该位置上有用户，将下麦该用户"
        case .release:
            return "解封此连麦位"
        default:
            fatalError()
        }
    }
}
