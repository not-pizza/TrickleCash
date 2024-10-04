import SwiftUI

struct SpendingAvailability: View {
    var monthlyRate: Double
    
    private var dailyRate: Double {
        return monthlyRate * 12 / 365.0
    }
    
    private var secondsPerCent: Double {
        guard monthlyRate > 0 else { return 0 }
        return (30.0 * 24 * 60 * 60) / (monthlyRate * 100)
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 15) {
            Text("This means you can spend").bold()
            Text("$\(monthlyRate, specifier: "%.0f") every month")
            Text("$\(dailyRate, specifier: "%.0f") every day")
            Text("1¢ every \(secondsPerCent, specifier: "%.0f") seconds")
        }
        .padding()
        .background(Color.secondary.opacity(0.2))
        .cornerRadius(10)
    }
    
}

struct Intro: View {
    @State private var monthlyRateString: String = "1000"
    @State private var showingDetails: Bool = false
    @State private var currentPage: Int = 1 // New state variable to track the current page
    @State private var currentTime: Date = Date()
    @State private var startDate: Date = Date()
    @FocusState private var focusedField: Bool
    
    @Environment(\.colorScheme) var colorScheme
    
    var gradientColors: [Color] {
        colorScheme == .dark ?
        [Color.black] :
        [Color.white]
    }

    
    var finishIntro: (AppData) -> Void
    
    private var monthlyRate: Double {
        return toDouble(monthlyRateString) ?? 0
    }
        
    private var appData: AppData {
        AppData(
            monthlyRate: monthlyRate,
            startDate: startDate,
            events: [],
            watchedHomeSceenWidgetTutorial: nil,
            watchedLockSceenWidgetTutorial: nil,
            watchedShortcutTutorial: nil
        )
    }
    
    var monthlyRateTextInput: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.2))
            TextField("Enter amount", text: $monthlyRateString)
                .keyboardType(.decimalPad)
                .focused($focusedField)
                .padding()
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: gradientColors),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                ScrollView {
                    VStack(spacing: 30) {
                        Text("Trickle")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Stay on budget throughout the month")
                            .font(.title2)
                        
                        if currentPage == 1 {
                            VStack(spacing: 30) {
                                Text("Your monthly budget\nNot including bills and subscriptions:")
                                    .multilineTextAlignment(.center)
                                    .lineLimit(nil)
                                    .frame(height: 50)
                                
                                HStack {
                                    Text("$")
                                    monthlyRateTextInput
                                }
                            }
                            .padding()
                            
                            SpendingAvailability(monthlyRate: monthlyRate)
                        }
                        else if currentPage == 2 {
                            Text("This balance shows how much money you would have if you got paid 1¢ every \((30.0 * 24 * 60 * 60) / (monthlyRate * 100), specifier: "%.0f") seconds:")
                                .multilineTextAlignment(.center)
                                .font(.headline)
                                .padding()
                            
                            CircularBalanceView(appData: appData, currentTime: currentTime, frameSize: 200)

                            Text("Log your spending and we'll deduct it from your balance. This lets you keep track of how much money you have left to spend")
                                .multilineTextAlignment(.center)
                                .font(.headline)
                                .padding()
                        } else {
                            Text("All spending needs to be logged manually in Trickle. Stay positive, stay on track, and make your financial goals a reality!")
                                .multilineTextAlignment(.center)
                                .padding()
                                .font(.title2)
                        }
                    }
                    .padding()
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    if currentPage > 1 {
                        // Back button
                        Button(action: {
                            currentPage -= 1
                        }) {
                            Image(systemName: "arrow.left")
                                .foregroundColor(.blue)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                        }
                    }
                    
                    Spacer()
                    
                    // Next/Finish button
                    if focusedField == false {
                        Button(action: {
                            if currentPage == 3 {
                                finishIntro(appData)
                            }
                            currentPage = min(currentPage + 1, 3)
                        }) {
                            Text(currentPage == 3 ? "Finish" : "Next")
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .cornerRadius(10)
                        .disabled(toDouble(monthlyRateString) == nil)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            setupTimer()
        }
    }
    
    
    private func setupTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            currentTime = Date()
        }
    }

}

#Preview {
    return Intro(finishIntro: {_ in ()})
}
