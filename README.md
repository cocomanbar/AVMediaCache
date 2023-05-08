# AVMediaCache

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

AVMediaCache is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby

pod 'AVMediaCache'


目前支持MP4边下边播，以及按进度或大小预加载文件

AVMediaCache:
    - mediaCacheLimit   设置最大缓存值
    - reportClosure     播放异常上报
    
    - mediaForAsset:        MP4链接通过此获取的AVURLAsset具备缓存能力
    - mediaForPlayerItem:   MP4链接通过此获取的AVPlayerItem具备缓存能力
    
借鉴HTTPKVTCache作者的片段缓存设计

source data total length

  0                           100     
| ------------------------------- |


local data section
 5  26        56   89 
| --- |      | ---- |       


total section sort

  0~4    5~26    27~55    56~89  90~100
| ----   -----  -------  ------  ------ |    
   net   local    net     local    net
    a      l1      b       l2       c


and net-sections will be download when playing at the same time if it needed.
a - l1 - b - l2 - c


now, if seek to 0 and play:
    a - l1[5~26] - b - l2[56~89] - c
    -> a -> b -> c  and a/b/c will to download if it needed


now, if seek to 20 and play:
    l1[20~26] - b - l2 - c
    -> b -> c  and b/c will to download if it needed


未来计划
todo: cahce m3u8

m3u8分为1级和2级，目前最多2级但较复杂，计划支持1级的缓存
m3u8  index.file
         01.ts
         02.ts
         03.ts
         ...        
no range, when playing and cahce -ts segments

```

## Author

tanxl, 125322078@qq.com

## License

AVMediaCache is available under the MIT license. See the LICENSE file for more info.
