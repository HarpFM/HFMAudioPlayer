//
//  HFMAudioManagerDelegate.swift
//  HarpFM
//
//  Created by Brian Drelling on 2/10/17.
//  Copyright © 2017 Harp.fm. All rights reserved.
//

import Foundation

protocol HFMAudioManagerDelegate {
    /// Return the information that is loaded into MPNowPlayingInfoCenter.default().nowPlayingInfo and displayed on the lock screen and other locations.
    ///
    /// - Returns: [String: Any]? (keys must match MPMediaItem keys)
    func getNowPlayingInfo() -> [String : Any]?
    
    /// Fires whenever an audio player update is requested. Timing is controlled by HFMAudioManager.updateInterval.
    ///
    /// - Parameter player: HFMAudioPlayer
    func onAudioPlayerUpdateRequested(_ player: HFMAudioPlayer)
    
    /// Fires whenever MPNowPlayingInfoCenter.default().nowPlayingInfo gets updated (minus album art).
    func onNowPlayingInfoUpdated()
    
    /// Fires immediately after onNowPlayingInfoUpdated. Should be used to call HFMAudioManager.updateNowPlayingAlbumArt. 
    /// This call must be made manually to allow for asynchronous updates.
    func onNowPlayingAlbumArtRequested()
    
    /// Fires whenever onAudioPlayerUpdateRequested fires and the HFMAudioManager.timeSinceLastSync is greater than HFMAudioManager.syncInterval.
    /// This call is a utility method used to synchronize updates with a server and meant to be called less frequently than onAudioPlayerUpdateRequested.
    func onSyncRequested()
}
