import SwiftUI

struct TutorialItem: Identifiable {
    let id = UUID()
    let videoName: String
    let videoTitle: String
    var watched: Binding<Date?>
}

struct TutorialListView: View {
    var tutorials: [TutorialItem]
    var closeTutorials: (() -> Void)?

    @State private var selectedTutorial: TutorialItem?

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Get Started")
                    .font(.headline)
                Spacer()
                if let closeTutorials = closeTutorials {
                    Button(action: {
                        closeTutorials()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.top)

            VStack {
                ForEach(tutorials) { tutorial in
                    let isWatched = Binding<Bool>(
                        get: { tutorial.watched.wrappedValue != nil },
                        set: { newValue in
                            tutorial.watched.wrappedValue = newValue ? Date() : nil
                        }
                    )

                    Button(action: {
                        selectedTutorial = tutorial
                        tutorial.watched.wrappedValue = Date()
                    }) {
                        HStack {
                            Toggle(isOn: isWatched) {
                                Text(tutorial.videoTitle)
                                    .strikethrough(isWatched.wrappedValue)
                            }
                            .toggleStyle(CheckboxToggleStyle())

                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                }
            }
        }
        .sheet(item: $selectedTutorial) { tutorial in
            TutorialVideoPlayer(
                videoName: tutorial.videoName,
                videoTitle: tutorial.videoTitle,
                isPresented: $selectedTutorial
            )
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
        TutorialItem(
            videoName: "add-home-screen-widget",
            videoTitle: "Add a Home Screen Widget",
            watched: .constant(nil)
        ),
        TutorialItem(
            videoName: "add-lock-screen-widget",
            videoTitle: "Add a Lock Screen Widget",
            watched: .constant(nil)
        ),
    ]
    
    static var previews: some View {
        TutorialListView(tutorials: tutorials, closeTutorials: {})
    }
}

func getTutorialItems(appData: Binding<AppData>) -> [TutorialItem] {
    var tutorials: [TutorialItem] = []
    tutorials.append(
        TutorialItem(
            videoName: "add-home-screen-widget",
            videoTitle: "Add a Home Screen Widget",
            watched: Binding(get: {appData.wrappedValue.watchedHomeSceenWidgetTutorial}, set: {appData.wrappedValue.watchedHomeSceenWidgetTutorial = $0})
        )
    )
    tutorials.append(
        TutorialItem(
            videoName: "add-lock-screen-widget",
            videoTitle: "Add a Lock Screen Widget",
            watched: Binding(get: {appData.wrappedValue.watchedLockSceenWidgetTutorial}, set: {appData.wrappedValue.watchedLockSceenWidgetTutorial = $0})
        )
    )
    tutorials.append(
        TutorialItem(
            videoName: "Add a shortcut to trickle",
            videoTitle: "Add iPhone Payments Automatically",
            watched: Binding(get: {appData.wrappedValue.watchedShortcutTutorial}, set: {appData.wrappedValue.watchedShortcutTutorial = $0})
        )
    )
    return tutorials
}

