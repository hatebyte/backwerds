//
//  CMAudioRecorderViewController.swift
//  RecordReversedSound
//
//  Created by Scott Jones on 12/30/15.
//  Copyright © 2015 Barf. All rights reserved.
//

import UIKit
import AVFoundation
import AssetsLibrary

class CMAudioRecorderViewController: UIViewController, CYOutputDataSource, CMAudioRecoredSampleBufferDelegate, CYAudioFileWriterErrorDelegate {
    
    var fileWriter:CYAudioFileWriter?
    var audioRecorder:CMAudioRecorder?
    
    var fileReader : CYFileReader!
    var output : CYOutput!

    
    var fileLocalDirectory:String?
    var filePath:String?
    var player:AVAudioPlayer!
    var dirPath:String = "recording"
    var backgroundTask:UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    var startTime = CMTime()
    var sampleBuffers = [CMSampleBuffer]()
    
    var masterPath:String?
    var challengePath:String?
    
    var theView:CMAudioRecorderView {
        return self.view as! CMAudioRecorderView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        output = CYOutput()
        output.outputDataSource = self
        
        self.automaticallyAdjustsScrollViewInsets           = false
        self.theView.didLoad()
   
        self.fileLocalDirectory                             = CYFileManager.default().documentDirectoryPath(forName: self.dirPath)
        _                                                   = NSURL.fileURL(withPath: self.fileLocalDirectory!, isDirectory: true).deletingLastPathComponent
        CYFileManager.default().clearFiles(fromDirectory: self.fileLocalDirectory)
        
        CMAudioRecorder.shouldTry { (granted:Bool) -> Void in
            if granted == true {
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let nc                                              = NotificationCenter.default
        nc.addObserver(self, selector: #selector(willEnterBackground), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        nc.addObserver(self, selector: #selector(willEnterForeground), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let nc                                              = NotificationCenter.default
        nc.removeObserver(self, name: NSNotification.Name.UIApplicationWillResignActive, object:nil)
        nc.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object:nil)
        
        self.removeButtonHandlers()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.view.layoutIfNeeded();
        self.addButtonHandlers()
    }
    
//    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
//        return UIInterfaceOrientationMask.portrait
//    }
//
//    override func preferredStatusBarStyle() -> UIStatusBarStyle {
//        return UIStatusBarStyle.lightContent
//    }
//
//    override func prefersStatusBarHidden() -> Bool {
//        return false
//    }
//
//    override func shouldAutorotate() -> Bool {
//        return true
//    }
    
    private func addButtonHandlers() {
        self.theView.recordMasterButton!.addTarget(self,    action: #selector(recordMaster),   for: .touchUpInside)
        self.theView.playMasterButton!.addTarget(self,      action: #selector(playMaster),    for: .touchUpInside)
        self.theView.recordChallengeButton!.addTarget(self,       action: #selector(recordChallenge), for: .touchUpInside)
        self.theView.playChallengeButton!.addTarget(self,         action: #selector(playChallenge),  for: .touchUpInside)
    }
    
    private func removeButtonHandlers() {
        self.theView.recordMasterButton!.removeTarget(self,     action: #selector(recordMaster),   for: .touchUpInside)
        self.theView.playMasterButton!.removeTarget(self,       action: #selector(playMaster),    for: .touchUpInside)
        self.theView.recordChallengeButton!.removeTarget(self,  action: #selector(recordChallenge), for: .touchUpInside)
        self.theView.playChallengeButton!.removeTarget(self,    action: #selector(playChallenge),  for: .touchUpInside)
    }
    
    // MARK: buttonhandler
    @objc func recordMaster() {
        self.theView.recordMasterButton!.removeTarget(self,     action: #selector(recordMaster),   for: .touchUpInside)
        self.theView.recordMasterButton!.addTarget(self,     action: #selector(stopRecordingMaster),   for: .touchUpInside)
        self.theView.showForMasterRecording()
        self.startRecording()
    }
    
    @objc func stopRecordingMaster() {
        self.theView.recordMasterButton!.removeTarget(self,     action: #selector(stopRecordingMaster),   for: .touchUpInside)
        self.stopRecording { [unowned self] (path:String) in
            self.masterPath = path;
            self.theView.showDefault()
            self.theView.recordMasterButton!.addTarget(self,     action: #selector(self.recordMaster),   for: .touchUpInside)
        }
    }
  
    @objc func playMaster() {
        if let masterP = self.masterPath {
            self.theView.playMasterButton!.removeTarget(self,     action: #selector(playMaster),   for: .touchUpInside)
            self.theView.playMasterButton!.addTarget(self,     action: #selector(stopPlayingMaster),   for: .touchUpInside)
            self.theView.showForMasterPlaying()
            self.fileReader = CYFileReader(fileUrl: NSURL(fileURLWithPath:masterP) as URL!)
            self.startPlayingFile()
        }
    }
   
    @objc func stopPlayingMaster() {
        self.stopPlayingFile()
        self.theView.showDefault()
        self.theView.playMasterButton!.removeTarget(self,     action: #selector(stopPlayingMaster),   for: .touchUpInside)
        self.theView.playMasterButton!.addTarget(self,     action: #selector(playMaster),   for: .touchUpInside)
    }
   
    @objc func recordChallenge() {
        self.theView.recordChallengeButton!.removeTarget(self,  action: #selector(recordChallenge), for: .touchUpInside)
        self.theView.recordChallengeButton!.addTarget(self,     action: #selector(stopRecordingChallenge),   for: .touchUpInside)
        self.theView.showForChallengeRecording()
        self.startRecording()
    }
    
    @objc func stopRecordingChallenge() {
        self.theView.recordChallengeButton!.removeTarget(self,     action: #selector(stopRecordingChallenge),   for: .touchUpInside)
        self.stopRecording { [unowned self] (path:String) in
            self.challengePath = path;
            self.theView.showDefault()
            self.theView.recordChallengeButton!.addTarget(self,     action: #selector(self.recordChallenge),   for: .touchUpInside)
        }
    }

    @objc func playChallenge() {
        if let challengeP = self.challengePath {
            self.theView.playChallengeButton!.removeTarget(self,     action: #selector(playChallenge),   for: .touchUpInside)
            self.theView.playChallengeButton!.addTarget(self,     action: #selector(stopPlayingChallenge),   for: .touchUpInside)
            self.theView.showForChallengePlaying()
            self.fileReader = CYFileReader(fileUrl: NSURL(fileURLWithPath:challengeP) as URL!)
            self.startPlayingFile()
        }
    }
    
    @objc func stopPlayingChallenge() {
        self.stopPlayingFile()
        self.theView.showDefault()
        self.theView.playChallengeButton!.removeTarget(self,     action: #selector(playChallenge),   for: .touchUpInside)
        self.theView.playChallengeButton!.addTarget(self,     action: #selector(playChallenge),   for: .touchUpInside)
    } 

    func startRecording() {
        self.fileReader = nil
        self.stopPlayingFile()
        self.fileWriter = nil
        CMAudioRecorder.shouldTry { [unowned self] (granted:Bool) -> Void in
            if granted {
                self.fileWriter                             = nil
                self.fileWriter                             = CYAudioFileWriter(fileName:self.dirPath, directory:self.fileLocalDirectory!)
                self.fileWriter?.errorDelegate              = self
                self.audioRecorder                          = CMAudioRecorder()
                self.audioRecorder?.sampleBufferDelegate    = self
                self.audioRecorder?.startRecordering()
            }
        }
    }
    
    func stopRecording(complete:@escaping CloseFile) {
        self.audioRecorder?.stopRecordering()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            while let sb = self?.sampleBuffers.popLast() {
                self?.fileWriter?.encodeSampleBuffer(sampleBuffer: sb, isVideo: false);
            }

            self?.fileWriter?.cutRecording(complete: { (path:String) in
                DispatchQueue.main.async { [weak self] in
                    complete(path)
                }
            })
        }
    }
    
    func startPlayingFile() {
        output.startUnit()
    }
    
    func stopPlayingFile() {
        output.stopUnit()
    }
    
    // MARK: CYOutputDataSource
    func readFrames(_ frames: UInt32, audioBufferList: UnsafeMutablePointer<AudioBufferList>, bufferSize: UnsafeMutablePointer<UInt32>) {
        if let reader = self.fileReader {
            reader.readFrames(frames, audioBufferList: audioBufferList, bufferSize: bufferSize)
        }
    }
    
    //MARK: CMSampleBufferDelegate
    func didRenderAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer!) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.sampleBuffers.append(sampleBuffer)
        }
    }
   
    //MARK: CYFileWriterErrorDelegate 
    func hdFileEncoderError(error:NSError) {
        print(error.localizedDescription)
    }
    
//    // MARK: InteruptionHandlers
    @objc func willEnterBackground() {
        backgroundTask                                      = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
            
        });
    }
    
    @objc func willEnterForeground() {
        if self.backgroundTask != UIBackgroundTaskInvalid {
            UIApplication.shared.endBackgroundTask(self.backgroundTask)
            self.backgroundTask                             = UIBackgroundTaskInvalid;
        }
    }
    
}




































