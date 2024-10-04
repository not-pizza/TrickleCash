//
//  video-player.swift
//  Pip Player
//
//  Created by Khondakar Afridi on 3/3/24.
//

import Foundation
import SwiftUI

struct PlayerView: View {
    @StateObject var playerController = PlayerController()
    var url: URL
    var title: String
    
    
    var body: some View {
        VStack(alignment: .center){
            GeometryReader { geometry in
                let parentWidth = geometry.size.width
                
                if playerController.player == nil {
                    Text("Loading")
                } else {
                    VideoPlayer(playerController: playerController)
                        .aspectRatio(19.5/9, contentMode: .fill)
                        .frame(width: parentWidth)
                }
            }
            .frame(width: 50)
        }
        .onAppear {
            playerController.initPlayer(title: title, link: url, artist: "not.pizza", artwork: "Trickle")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                playerController.playPlayer()
            }
        }
    }
}
