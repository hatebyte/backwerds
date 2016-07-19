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
        self.backgroundColor                           = UIColor.blackColor();
    }
    
    private func masterButtons(enabled enabled:Bool) {
        self.recordMasterButton?.enabled = enabled
        self.playMasterButton?.enabled = enabled
    }
    
    private func challengeButtons(enabled enabled:Bool) {
        self.recordChallengeButton?.enabled = enabled
        self.playChallengeButton?.enabled = enabled
    }
    
    func showDefault() {
        self.masterButtons(enabled:true)
        self.challengeButtons(enabled:true)
        self.recordMasterButton?.setTitle(NSLocalizedString("Record Master", comment: "recordMasterButton : Default"), forState: .Normal)
        self.playMasterButton?.setTitle(NSLocalizedString("Play Master", comment: "playMasterButton : Default"), forState: .Normal)
        self.recordChallengeButton?.setTitle(NSLocalizedString("Record Challenge", comment: "recordChallengeButton : Default"), forState: .Normal)
        self.playChallengeButton?.setTitle(NSLocalizedString("Play Master", comment: "playChallengeButton : Default"), forState: .Normal)
    }

    func showForMasterRecording() {
        self.challengeButtons(enabled:false)
        self.playMasterButton?.enabled = false
        self.recordMasterButton?.setTitle(NSLocalizedString("Stop", comment: "recordMasterButton : Recording"), forState: .Normal)
    }
   
    func showForMasterPlaying() {
        self.challengeButtons(enabled: false)
        self.recordMasterButton?.enabled = false
        self.playMasterButton?.setTitle(NSLocalizedString("Stop", comment: "playMasterButton : Playing"), forState: .Normal)
    }
    
    func showForChallengeRecording() {
        self.masterButtons(enabled:false)
        self.playChallengeButton?.enabled = false
        self.recordChallengeButton?.setTitle(NSLocalizedString("Stop", comment: "recordChallengeButton : Recording"), forState: .Normal)
    }
    
    func showForChallengePlaying() {
        self.masterButtons(enabled: false)
        self.recordChallengeButton?.enabled = false
        self.playChallengeButton?.setTitle(NSLocalizedString("Stop", comment: "playChallengeButton : Playing"), forState: .Normal)
    }


    
    
}
