//
//  ViewController.swift
//  AVMediaCache
//
//  Created by tanxl on 04/20/2023.
//  Copyright (c) 2023 tanxl. All rights reserved.
//

import UIKit
import AVFoundation
import AVMediaCache

class ViewController: UIViewController {

    var preloader: AVMediaCachePreloader?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        title = "See TouchesBegan."
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        junmFeed()
        
//        jumpSingle()
        
//        preload()
        
    }
    
    // test feed
    func junmFeed() {
        
        let controller = FeedController()
        navigationController?.pushViewController(controller, animated: true)
    }
    
    // test single mp4 or m3u8[to do]
    func jumpSingle() {
        
        let url = URL(string: "http://aliuwmp3.changba.com/userdata/video/45F6BD5E445E4C029C33DC5901307461.mp4")!
//        let url = URL(string: "https://bitmovin-a.akamaihd.net/content/playhouse-vr/m3u8s/105560_video_360_1000000.m3u8")!
        let controller = PlayerController(url: url)
        self.present(controller, animated: true)
    }
    
    func preload() {
        
        let urls = [
            "http://aliuwmp3.changba.com/userdata/video/45F6BD5E445E4C029C33DC5901307461.mp4",
            "https://media.w3.org/2010/05/sintel/trailer.mp4",
            "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4",
            "http://www.w3school.com.cn/example/html5/mov_bbb.mp4",
            "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4",
            "http://vfx.mtime.cn/Video/2021/07/10/mp4/210710171112971120.mp4",
            "http://vfx.mtime.cn/Video/2021/07/10/mp4/210710122716702150.mp4",
            "http://vfx.mtime.cn/Video/2021/07/10/mp4/210710095541348171.mp4",
            "http://vfx.mtime.cn/Video/2021/07/10/mp4/210710094507540173.mp4",
            "http://vfx.mtime.cn/Video/2021/07/09/mp4/210709224656837141.mp4"
        ]
        
        let URLs = urls.map({ URL(string: $0) }).compactMap({ $0 })
        preloader = AVMediaCachePreloader()
        preloader?.delegate = self
        preloader?.preloadUrls(URLs)
    }
}

extension ViewController: AVMediaCachePreloaderDelegate {
    
    func mediaPreload(_ preLoader: AVMediaCachePreloader, completeUrl: URL, error: Error?) {
        print("didCompleteUrl === \(completeUrl) error === \(String(describing: error))")
    }
    
    func mediaPreload(_ preLoader: AVMediaCachePreloader, currentUrl: URL) {
        print("currentUrl === \(currentUrl)")
    }
}
