//
//  PlayerController.swift
//  Pip Player
//
//  Created by Khondakar Afridi on 3/3/24.
//

import Foundation
import AVKit

class PlayerController: ObservableObject{
    @Published var url: URL?
    @Published var playbackTitle: String = ""
    @Published var playbackArtist: String = ""
    @Published var playbackArtwork: String = ""
    
    var player: AVPlayer?
    var avPlayerViewController: AVPlayerViewController = AVPlayerViewController()
    
    func initPlayer(
        title: String,
        link: URL,
        artist: String,
        artwork: String){
            self.playbackTitle = title
            self.playbackArtist = artist
            self.playbackArtwork = artwork
            self.url = link
            
            setupPlayer()
            setupAVPlayerViewController()
        }
    
    private func setupPlayer(){
        player = AVPlayer(url: url!)
        
        let title = AVMutableMetadataItem()
        title.identifier = .commonIdentifierTitle
        title.value = playbackTitle as NSString
        title.extendedLanguageTag = "eng"
        
        let artist = AVMutableMetadataItem()
        artist.identifier = .commonIdentifierArtist
        artist.value = playbackArtist as NSString
        artist.extendedLanguageTag = "und"
        
        let artwork = AVMutableMetadataItem()
        if let image = UIImage(named: "Artist") {
            if let imageData = image.jpegData(compressionQuality: 1.0) {
                artwork.identifier = .commonIdentifierArtwork
                artwork.value = imageData as NSData
                artwork.dataType = kCMMetadataBaseDataType_JPEG as String
                artwork.extendedLanguageTag = "und"
            }
        }
        
        player?.currentItem?.externalMetadata = [title, artist, artwork]
    }
    
    private func setupAVPlayerViewController(){
        avPlayerViewController.player = player
        avPlayerViewController.allowsPictureInPicturePlayback = true
        avPlayerViewController.canStartPictureInPictureAutomaticallyFromInline = true
    }
    
    func pausePlayer(){
        player?.pause()
    }
    
    func playPlayer(){
        player?.play()
    }
    
}
