//
//  PlayerController.swift
//  AVMediaCache_Example
//
//  Created by tanxl on 2023/4/23.
//  Copyright © 2023 CocoaPods. All rights reserved.
//

import UIKit
import AVKit
import AVMediaCache

class PlayerController: AVPlayerViewController {
    
    private var url: URL
    
    init(url: URL) {
        self.url = url
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let playItem = AVMediaCache.shared.mediaForPlayerItem(url: url)
        let player = AVPlayer(playerItem: playItem)
        player.volume = 1.0
        player.play()
        player.automaticallyWaitsToMinimizeStalling = false // important
        self.player = player
    }
    
    deinit {
        player?.currentItem?.asset.cancelLoading()
        player?.currentItem?.cancelPendingSeeks()
        player?.cancelPendingPrerolls()
    }
}
