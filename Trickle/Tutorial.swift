import SwiftUI

struct TutorialVideoPlayer: View {
    let videoName: String
    @State var isPresented = true
    
    var body: some View {
        PlayerView()
    }
}
