import SwiftUI

struct TutorialItem: Identifiable {
    let id = UUID()
    let title: String
    let videoName: String
    let videoTitle: String
}

struct TutorialListView: View {
    @Binding var completedTutorials: Set<UUID>
    let tutorials: [TutorialItem]
    @State private var selectedTutorial: TutorialItem?
    
    var body: some View {
        VStack {
            Text("Next Steps")
                .font(.headline)
                .padding(.top)
            
            List(tutorials) { tutorial in
                HStack {
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
                                Text(tutorial.title)
                            }
                            .toggleStyle(CheckboxToggleStyle())
                            
                            Spacer()
                            
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                    }
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
