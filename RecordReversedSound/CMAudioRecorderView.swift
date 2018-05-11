//
//  CMAudioRecorderView.swift
//  RecordReversedSound
//
//  Created by Scott Jones on 1/2/16.
//  Copyright © 2016 Barf. All rights reserved.
//

import UIKit

class CMAudioRecorderView: UIView {

    @IBOutlet var recordMasterButton:UIButton?
    @IBOutlet var playMasterButton:UIButton?
    @IBOutlet var recordChallengeButton:UIButton?
    @IBOutlet var playChallengeButton:UIButton?
    
    func didLoad() {
        self.autoresizesSubviews                       = true;
        self.backgroundColor                           = UIColor.black;
    }
    
    private func masterButtons(isEnabled:Bool) {
        self.recordMasterButton?.isEnabled = isEnabled
        self.playMasterButton?.isEnabled = isEnabled
    }
    
    private func challengeButtons(isEnabled:Bool) {
        self.recordChallengeButton?.isEnabled = isEnabled
        self.playChallengeButton?.isEnabled = isEnabled
    }
    
    func showDefault() {
        self.masterButtons(isEnabled:true)
        self.challengeButtons(isEnabled:true)
        self.recordMasterButton?.setTitle(NSLocalizedString("Record Master", comment: "recordMasterButton : Default"), for: .normal)
        self.playMasterButton?.setTitle(NSLocalizedString("Play Master", comment: "playMasterButton : Default"), for: .normal)
        self.recordChallengeButton?.setTitle(NSLocalizedString("Record Challenge", comment: "recordChallengeButton : Default"), for: .normal)
        self.playChallengeButton?.setTitle(NSLocalizedString("Play Master", comment: "playChallengeButton : Default"), for: .normal)
    }

    func showForMasterRecording() {
        self.challengeButtons(isEnabled:false)
        self.playMasterButton?.isEnabled = false
        self.recordMasterButton?.setTitle(NSLocalizedString("Stop", comment: "recordMasterButton : Recording"), for: .normal)
    }
   
    func showForMasterPlaying() {
        self.challengeButtons(isEnabled: false)
        self.recordMasterButton?.isEnabled = false
        self.playMasterButton?.setTitle(NSLocalizedString("Stop", comment: "playMasterButton : Playing"), for: .normal)
    }
    
    func showForChallengeRecording() {
        self.masterButtons(isEnabled:false)
        self.playChallengeButton?.isEnabled = false
        self.recordChallengeButton?.setTitle(NSLocalizedString("Stop", comment: "recordChallengeButton : Recording"), for: .normal)
    }
    
    func showForChallengePlaying() {
        self.masterButtons(isEnabled: false)
        self.recordChallengeButton?.isEnabled = false
        self.playChallengeButton?.setTitle(NSLocalizedString("Stop", comment: "playChallengeButton : Playing"), for: .normal)
    }


    
    
}
