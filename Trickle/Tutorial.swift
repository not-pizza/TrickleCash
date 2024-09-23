import SwiftUI

struct TutorialItem: Identifiable {
    let id = UUID()
    let videoName: String
    let videoTitle: String
}

struct TutorialListView: View {
    @Binding var completedTutorials: Set<UUID>
    let tutorials: [TutorialItem]
    @State private var selectedTutorial: TutorialItem?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Get Started")
                .font(.headline)
                .padding(.top)
            
            VStack {
                ForEach(tutorials) { tutorial in
                    Button(action: { selectedTutorial = tutorial }) {
                        HStack {
                            Toggle(isOn: Binding(
                                get: { completedTutorials.contains(tutorial.id) },
                                set: { newValue in
                                    if newValue {
                                        completedTutorials.insert(tutorial.id)
                                    } else {
                                        completedTutorials.remove(tutorial.id)
                                    }
                                }
                            )) {
                                Text(tutorial.videoTitle)
                            }
                            .toggleStyle(CheckboxToggleStyle())
                            
                            Spacer()
                            
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(10)
                    }.buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $selectedTutorial) { tutorial in
            TutorialVideoPlayer(videoName: tutorial.videoName, videoTitle: tutorial.videoTitle, isPresented: $selectedTutorial)
        }
    }
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? .blue : .gray)
                .onTapGesture {
                    configuration.isOn.toggle()
                }
            configuration.label
        }
    }
}

struct TutorialVideoPlayer: View {
    let videoName: String
    let videoTitle: String
    @Binding var isPresented: TutorialItem?
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("Done") {
                    isPresented = nil
                }
                .padding()
            }
            
            if let videoURL = Bundle.main.url(forResource: videoName, withExtension: "mp4") {
                PlayerView(url: videoURL, title: videoTitle)
            } else {
                Text("Video not found")
            }
        }
    }
}


struct TutorialListView_Previews: PreviewProvider {
    static let tutorials = [
        TutorialItem(videoName: "add-home-screen-widget", videoTitle: "Add a Home Screen Widget"),
        TutorialItem(videoName: "add-lock-screen-widget", videoTitle: "Add a Lock Screen Widget"),
    ]
    
    static var previews: some View {
        TutorialListView(completedTutorials: .constant(Set<UUID>()), tutorials: tutorials)
    }
}
