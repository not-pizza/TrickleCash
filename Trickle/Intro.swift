import SwiftUI

struct Intro: View {
    @State private var monthlyRateString: String = "1000"
    @State private var showingDetails: Bool = false
    @State private var currentPage: Int = 1 // New state variable to track the current page
    @State private var currentTime: Date = Date()
    @State private var startDate: Date = Date()
    var finishIntro: (AppData) -> Void
    
    private var monthlyRate: Double {
        return toDouble(monthlyRateString) ?? 0
    }
    
    private var dailyRate: Double {
        return monthlyRate * 12 / 365.0
    }
    
    private var secondsPerCent: Double {
        guard monthlyRate > 0 else { return 0 }
        return (30.0 * 24 * 60 * 60) / (monthlyRate * 100)
    }
    
    private var appData: AppData {
        AppData(
            monthlyRate: monthlyRate,
            startDate: startDate,
            events: []
        )
    }
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Welcome to Trickle")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Stay on budget throughout the month")
                    .font(.title3)
                    .foregroundColor(.white)
                
                
                if currentPage == 1 {
                    VStack(spacing: 30) {
                        Text("Your monthly budget\nNot including bills and subscriptions:")
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .frame(height: 50)
                        
                        HStack {
                            Text("$")
                                .foregroundColor(.white)
                            TextField("Enter amount", text: $monthlyRateString)
                                .keyboardType(.decimalPad)
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    
                    VStack(alignment: .leading, spacing: 15) {
                        Text("$\(monthlyRate, specifier: "%.0f") per month")
                        Text("$\(dailyRate, specifier: "%.2f") per day")
                        Text("1 cent every \(secondsPerCent, specifier: "%.0f") seconds")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(10)
                    
                    Spacer()
                }
                // Display different text based on the current page
                else if currentPage == 2 {
                    Spacer()
                    Text("Watch your money trickle into your virtual wallet:")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .font(.headline)
                        .padding()
                    
                    CircularBalanceView(appData: appData, currentTime: currentTime, frameSize: 200)

                    Text("Log your spending and we'll deduct it from your balance.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .font(.headline)
                        .padding()
                    Spacer()
                } else {
                    Spacer()
                    Text("Stay positive, stay on track, and make your financial goals a reality.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding()
                        .font(.headline)
                    Spacer()
                }
                
                
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
                    Button(action: {
                        currentPage = min(currentPage + 1, 3)
                        if currentPage == 3 {
                            // You can add any action here for when they finish both pages
                            print("Finished introduction")
                        }
                    }) {
                        Text(currentPage == 2 ? "Next" : "Finish")
                            .foregroundColor(.blue)
                            .padding()
                            .background(toDouble(monthlyRateString) == nil ? Color.gray : Color.white)
                            .cornerRadius(10)
                    }.disabled(toDouble(monthlyRateString) == nil)
                }
                .padding()
            }
            .padding()
        }.onAppear() {
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
    return Intro()
}
