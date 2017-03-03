//
//  HFMAudioManager.swift
//  HarpFM
//
//  Created by Brian Drelling on 10/24/16.
//  Copyright © 2016 Brian Drelling. All rights reserved.
//

import AVFoundation
import Foundation
import MediaPlayer

open class HFMAudioManager: NSObject, HFMAudioManagerDelegate {
    // MARK: - Shared Instance
    
    private static var _shared: HFMAudioManager!
    
    open class var shared: HFMAudioManager {
        if (self._shared == nil) {
            self._shared = HFMAudioManager()
        }
        
        return self._shared
    }
    
    // MARK: - Enums
    
    public enum SkipDirection {
        case backward
        case forward
    }
    
    // MARK: - Properties
    
    open var audioSessionCategory: String = AVAudioSessionCategoryPlayback
    open var audioSessionMode: String = AVAudioSessionModeDefault
    open var delegate: HFMAudioManagerDelegate?
    open var isDebugEnabled = false
    open var supportedPlaybackRates: [NSNumber] = [1, 1.5, 2]
    open var preferredSkipBackwardIntervals: [NSNumber] = [-15, -30]
    open var preferredSkipForwardIntervals: [NSNumber] = [15, 30]
    open var syncInterval: TimeInterval?
    open var updateInterval: TimeInterval = 1
    
    public dynamic var player: HFMAudioPlayer? {
        willSet {
            self.player?.deinitialize()
        }
    }
    
//    // TODO: This whole block doesn't make sense
//    public var shouldPauseWhenExternalDeviceChanges = true {
//        didSet {
//            if (self.shouldPauseWhenExternalDeviceChanges) {
//                NotificationCenter.default.addObserver(self, selector: #selector(self.onAudioSessionRouteChanged), name: NSNotification.Name.AVAudioSessionRouteChange, object: nil)
//                NotificationCenter.default.addObserver(self, selector: #selector(self.onAudioSessionInterrupted), name: NSNotification.Name.AVAudioSessionInterruption, object: nil)
//                NotificationCenter.default.addObserver(self, selector: #selector(self.onAudioPlayerDidFinishPlaying), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
//            } else {
//                NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVAudioSessionRouteChange, object: nil)
//                NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVAudioSessionInterruption, object: nil)
//                NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
//            }
//        }
//    }
    
    private var shouldResumeAfterInterruption: Bool = false
    private var timeSinceLastSync: TimeInterval = 0
    private var updateTimer: Timer?
    
    // MARK: - Methods
    
    // MARK: Initializers
    
    public override init() {
        super.init()
        
        self.delegate = self
        self.delegate?.setProperties()
        
        self.addRemoteCommandHandlers()
        self.setAudioSession()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.onAudioSessionRouteChanged), name: NSNotification.Name.AVAudioSessionRouteChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onAudioSessionInterrupted), name: NSNotification.Name.AVAudioSessionInterruption, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onAudioPlayerDidFinishPlaying), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        
        self.addObserver(self, forKeyPath: #keyPath(player.status), options: [.old, .new], context: nil)
    }
    
    // MARK: Overrides
    
    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if (keyPath == #keyPath(player.status)) {
            self.onAudioPlayerStatusChanged(status: self.player?.status)
        }
    }
    
    // MARK: Events
    
    @objc
    private func onAudioPlayerDidFinishPlaying(notification: Notification) {
        var q = ""
    }
    
    @objc
    private func onAudioSessionInterrupted(notification: Notification) {
//        if let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt {
//            if (options == AVAudioSessionInterruptionOptions.shouldResume) {
//                var a = ""
//            }
//        }
        
        guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else {
            return
        }
        
        if (type == AVAudioSessionInterruptionType.began.rawValue) {
            self.shouldResumeAfterInterruption = self.player?.status == .playing
        } else if (type == AVAudioSessionInterruptionType.ended.rawValue) {
            if (self.shouldResumeAfterInterruption) {
                try? self.setActive(true)
                self.play()
                self.shouldResumeAfterInterruption = false
            }
        }
    }
    
    @objc
    private func onAudioSessionRouteChanged(notification: Notification) {
        guard let routeChangeReasonInt = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let routeChangeReason = AVAudioSessionRouteChangeReason(rawValue: routeChangeReasonInt) else {
                return
        }
        
        if (routeChangeReason == .oldDeviceUnavailable) {
            self.pause()
        }
    }
    
    // MARK: Player Commands
    
    open func pause() {
        self.player?.pause()
        
        if (self.isDebugEnabled) {
            print("Playback paused.")
        }
        
        self.stopTimer()
        
        self.requestAudioPlayerUpdate(shouldUpdateNowPlayingInfo: true)
    }
    
    open func play() {
        self.player?.play()
        
        if (self.isDebugEnabled) {
            print("Playback started.")
        }
        
//        try? self.setActive(true)
        self.startTimer()
        
        self.requestAudioPlayerUpdate(shouldUpdateNowPlayingInfo: true)
    }
    
    open func seek(to time: TimeInterval) {
        self.player?.seek(to: time) { [weak self] in
            self?.requestAudioPlayerUpdate(shouldUpdateNowPlayingInfo: true)
        }
        
        if (self.isDebugEnabled) {
            print("Playback seeked to \(time).")
        }
    }
    
    open func setPlaybackRate(to rate: Float) {
        self.player?.setPlaybackRate(to: rate)
        
        if (self.isDebugEnabled) {
            print("Playback rate set to \(rate).")
        }
        
        self.requestAudioPlayerUpdate(shouldUpdateNowPlayingInfo: true)
    }
    
    open func skip(by seconds: TimeInterval) {
        self.player?.skip(by: seconds) { [weak self] in
            self?.requestAudioPlayerUpdate(shouldUpdateNowPlayingInfo: true)
        }
        
        if (self.isDebugEnabled) {
            print("Playback skipped backward by \(seconds) seconds.")
        }
    }
    
    open func skip(_ direction: SkipDirection) {
        switch (direction) {
        case .backward:
            self.skip(by: -15)
        case .forward:
            self.skip(by: 15)
        }
    }
    
    open func stop() {
        self.player?.stop()
        
        if (self.isDebugEnabled) {
            print("Playback stopped.")
        }
        
        self.stopTimer()
        
        self.requestAudioPlayerUpdate(shouldUpdateNowPlayingInfo: true)
        
        try? self.setActive(false)
    }
    
    open func togglePlayPause() {
        if (player?.isPlaying != false) {
            self.pause()
        } else {
            self.play()
        }
    }
    
    // MARK: Utilities (Public)
    
    @discardableResult
    final public func prepareToPlay(filePath: String?, time: TimeInterval? = nil, persist: Bool = false) throws -> Bool {
        guard let filePath = filePath else {
            return false
        }
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        
        guard let fileURL = documentsURL?.appendingPathComponent(filePath) else {
            return false
        }
        
        return try self.prepareToPlay(fileURL: fileURL, time: time, persist: persist)
    }
    
    @discardableResult
    final public func prepareToPlay(fileURL: URL?, time: TimeInterval? = nil, persist: Bool = false) throws -> Bool {
        guard let fileURL = fileURL else {
            return false
        }
        
        if (!FileManager.default.fileExists(atPath: fileURL.path)) {
            return false
        }
        
        return try self.prepareToPlay(url: fileURL, time: time, persist: persist)
    }
    
    @discardableResult
    final public func prepareToPlay(url: URL?, time: TimeInterval? = nil, persist: Bool = false) throws -> Bool {
        guard let url = url else {
            return false
        }
        
        // Ignore prepare request if it's the actively playing file
        if (self.player?.url == url) {
            return false
        }
        
        if (persist) {
            self.player?.load(url: url, time: time)
        } else {
            self.clearNowPlayingInfo()
            
            self.player = HFMAudioPlayer(url: url, time: time)
        }
        
        try self.setActive(true)
        
        return self.player != nil
    }
    
    @objc
    final public func requestAudioPlayerUpdate(shouldUpdateNowPlayingInfo: Bool = false) {
        if (shouldUpdateNowPlayingInfo) {
            self.updateNowPlayingInfo()
        }
        
        if let player = self.player {
            self.delegate?.onAudioPlayerUpdateRequested(player)
        }
        
        if let syncInterval = self.syncInterval {
            self.timeSinceLastSync += self.updateInterval
            
            if (self.timeSinceLastSync >= syncInterval) {
                self.delegate?.onSyncRequested()
                self.timeSinceLastSync = 0
            }
        }
    }
    
    open func setAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(self.audioSessionCategory, with: [])
            try AVAudioSession.sharedInstance().setMode(self.audioSessionMode)
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    /// Updates MPNowPlayingInfoCenter.nowPlayingInfo on the MPMediaItemPropertyArtwork key.
    /// Is called separately to account for asynchronous loading of the album artwork.
    ///
    /// - Parameter image: the album artwork to be displayed on the lock screen
    final public func updateNowPlayingAlbumArt(image: UIImage?) {
        guard let image = image, var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else {
            return
        }
        
        if #available(iOS 10.0, *) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { (size) -> UIImage in
                return image
            })
        } else {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: image)
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    // MARK: Utilities (Private)
    
    private func addRemoteCommandHandlers() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates = self.supportedPlaybackRates
        
        commandCenter.skipBackwardCommand.preferredIntervals = self.preferredSkipBackwardIntervals
        commandCenter.skipForwardCommand.preferredIntervals = self.preferredSkipForwardIntervals
        
        if #available(iOS 9.1, *) {
            commandCenter.changePlaybackPositionCommand.addTarget() { (event) -> MPRemoteCommandHandlerStatus in
                guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                    return MPRemoteCommandHandlerStatus.commandFailed
                }
                
                self.seek(to: event.positionTime)
                return MPRemoteCommandHandlerStatus.success
            }
        }
        
        commandCenter.changePlaybackRateCommand.addTarget() { (event) -> MPRemoteCommandHandlerStatus in
            guard let event = event as? MPChangePlaybackRateCommandEvent else {
                return MPRemoteCommandHandlerStatus.commandFailed
            }
            
            self.setPlaybackRate(to: event.playbackRate)
            return MPRemoteCommandHandlerStatus.success
        }
        
        commandCenter.nextTrackCommand.addTarget() { (event) -> MPRemoteCommandHandlerStatus in
            return MPRemoteCommandHandlerStatus.commandFailed
        }
        
        commandCenter.pauseCommand.addTarget() { (event) -> MPRemoteCommandHandlerStatus in
            self.pause()
            return MPRemoteCommandHandlerStatus.success
        }
        
        commandCenter.playCommand.addTarget() { (event) -> MPRemoteCommandHandlerStatus in
            self.play()
            return MPRemoteCommandHandlerStatus.success
        }
        
        commandCenter.previousTrackCommand.addTarget() { (event) -> MPRemoteCommandHandlerStatus in
            return MPRemoteCommandHandlerStatus.commandFailed
        }
        
        commandCenter.skipBackwardCommand.addTarget() { (event) -> MPRemoteCommandHandlerStatus in
            guard let event = event as? MPSkipIntervalCommandEvent else {
                return MPRemoteCommandHandlerStatus.commandFailed
            }
            
            self.skip(by: event.interval)
            return MPRemoteCommandHandlerStatus.success
        }
        
        commandCenter.skipForwardCommand.addTarget() { (event) -> MPRemoteCommandHandlerStatus in
            guard let event = event as? MPSkipIntervalCommandEvent else {
                return MPRemoteCommandHandlerStatus.commandFailed
            }
            
            self.skip(by: event.interval)
            return MPRemoteCommandHandlerStatus.success
        }
        
        commandCenter.stopCommand.addTarget() { (event) -> MPRemoteCommandHandlerStatus in
            self.stop()
            return MPRemoteCommandHandlerStatus.success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget() { (event) -> MPRemoteCommandHandlerStatus in
            self.togglePlayPause()
            return MPRemoteCommandHandlerStatus.success
        }
    }
    
    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    private func setActive(_ isActive: Bool) throws {
        try AVAudioSession.sharedInstance().setActive(isActive)
        self.setNowPlayingInfo()
        self.requestAudioPlayerUpdate(shouldUpdateNowPlayingInfo: true)
    }
    
    /// Sets the MPNowPlayingInfoCenter with values returned from HFMAudioManagerDelegate.getNowPlayingInfo
    private func setNowPlayingInfo() {
        guard let info = self.delegate?.getNowPlayingInfo() else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        
        self.delegate?.onNowPlayingAlbumArtRequested()
        
        self.requestAudioPlayerUpdate(shouldUpdateNowPlayingInfo: true)
    }
    
    /// Starts the timer that fire HFMAudioManager.requestAudioPlayerUpdate which fires every second unless HFMAudioManager.updateInterval is changed.
    private func startTimer() {
        self.updateTimer?.invalidate()
        
        guard let player = self.player else {
            return
        }
        
        let updateInterval = TimeInterval(player.playbackRate) / self.updateInterval
        
        if #available(iOS 10.0, *) {
            self.updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] (timer) in
                self?.requestAudioPlayerUpdate()
            }
        } else {
            self.updateTimer = Timer.scheduledTimer(timeInterval: updateInterval, target: self, selector: #selector(self.requestAudioPlayerUpdate), userInfo: nil, repeats: true)
        }
    }
    
    /// Stops the timers that fire HFMAudioManager.requestAudioPlayerUpdate which fires every second unless HFMAudioManager.updateInterval is changed.
    private func stopTimer() {
        self.updateTimer?.invalidate()
        self.updateTimer = nil
        
        if (self.isDebugEnabled) {
            print("Update timer stopped.")
        }
    }
    
    /// Updates MPNowPlayingInfoCenter.nowPlayingInfo with info relevant to the current instance of HFMAudioPlayer
    private func updateNowPlayingInfo() {
        guard let player = self.player  else {
                return
        }
        
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? self.getNowPlayingInfo() else {
            return
        }
        
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = player.playbackRate
        
        if (player.duration > 0) {
            info[MPMediaItemPropertyPlaybackDuration] = player.duration
            
            if #available(iOS 10.0, *) {
                info[MPNowPlayingInfoPropertyPlaybackProgress] = Float(player.currentTime / player.duration)
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        
        self.delegate?.onNowPlayingInfoUpdated()
    }
    
    open func getNowPlayingInfo() -> [String : Any]? { return nil }
    open func onAudioPlayerStatusChanged(status: HFMAudioPlayerStatus?) {}
    open func onAudioPlayerUpdateRequested(_ player: HFMAudioPlayer) { }
    open func onNowPlayingInfoUpdated() { }
    open func onNowPlayingAlbumArtRequested() { }
    open func onSyncRequested() { }
    open func setProperties() { }
}
