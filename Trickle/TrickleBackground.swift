import SwiftUI

struct IdentifiedBucket: Identifiable {
    let id: UUID
    let bucket: Bucket
}

struct BackgroundView: View {
    @Binding var appData: AppData
    var onSettingsTapped: () -> Void
    var foregroundShowingOffset: CGFloat
    var foregroundHidden: Bool
    var currentTime: Date

    @State private var editingBucket: IdentifiedBucket?
    @State private var isAddingNewBucket = false
    @State private var spacing = 60
    
    @Environment(\.colorScheme) var colorScheme
    
    var formatStyle: Date.RelativeFormatStyle {
        var formatStyle = Date.RelativeFormatStyle()
        formatStyle.presentation = .named
        return formatStyle
    }
    
    var body: some View {
        let appState = appData.getAppState(asOf: currentTime)
        let balance = appState.balance
        let perSecondRate = appState.totalIncomePerSecond - appState.bucketIncomePerSecond
        
        let timeAtZero = perSecondRate > 0 ? Calendar.current.date(byAdding: .second, value: Int(-balance / perSecondRate), to: currentTime) : nil
        let debtClock = timeAtZero?.formatted(formatStyle)
        
        let debtClockHeight = 20.0
        
        let buckets = Array(appState.buckets).map({(id, bucketInfo) in
            (
                id: id,
                amount: bucketInfo.amount,
                bucket: bucketInfo.bucket
            )
        }).sorted(by: {$0.bucket.name < $1.bucket.name}).sorted(by: {$0.bucket.estimatedCompletionDate < $1.bucket.estimatedCompletionDate})
        
        return ZStack(alignment: .top) {
            balanceBackgroundGradient(balance, colorScheme: colorScheme).ignoresSafeArea()
            
            let balanceHeight = (Double(foregroundShowingOffset) - 50.0) + (balance < 0 ? 0.0 : debtClockHeight + 10)
            
            VStack(alignment: .center) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Color.clear
                                    .frame(width: 24, height: 24)
                                Spacer()
                                
                                VStack(spacing: 10) {
                                    CircularBalanceView(appData: appData, currentTime: currentTime, frameSize: balanceHeight)
                                    if balance < 0 {
                                        if let debtClock = debtClock {
                                            Text("Out of debt \(debtClock)").frame(height: debtClockHeight)
                                        }
                                    }
                                }
                                
                                Spacer()
                                NavigationLink(
                                    destination: SettingsView(
                                        appData: $appData
                                    )) {
                                        Image(systemName: "gear")
                                            .foregroundColor(.primary)
                                            .font(.system(size: 26))
                                    }
                            }
                            .padding()
                            .frame(height: foregroundShowingOffset, alignment: .top)
                        }
                        .frame(height: foregroundShowingOffset, alignment: .top)
                        
                        
                        Spacer().frame(height: CGFloat(spacing))
                        
                        // Buckets
                        
                        Spacer().frame(height: 1)
                        VStack {
                            Button(action: {
                                isAddingNewBucket = true
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Add bucket")
                                    Spacer()
                                }
                                .frame(height: 30)
                            }
                            .buttonStyle(AddBucketButtonStyle())
                        }
                        .padding(.horizontal)
                        
                        Spacer().frame(height: 30)
                        
                        ForEach(buckets, id: \.id) { bucket in
                            BucketView(
                                id: bucket.id,
                                amount: bucket.amount,
                                bucket: Binding(
                                    get: { bucket.bucket },
                                    set: { newBucket in
                                        appData = appData.updateBucket(bucket.id, newBucket)
                                    }
                                ),
                                dump: {
                                    appData = appData.dumpBucket(bucket.id)
                                },
                                currentTime: currentTime
                            )
                            .onTapGesture {
                                editingBucket = IdentifiedBucket(id: bucket.id, bucket: bucket.bucket)
                            }
                        }
                        
                        if buckets.isEmpty {
                            Text("Buckets let you start saving a portion of your income for future expenses or bills. Add a bucket to get started!")
                                .padding()
                                .multilineTextAlignment(.center)
                        } else {
                            BudgetAllocationView(
                                totalIncomePerSecond: appState.totalIncomePerSecond,
                                bucketIncomePerSecond: appState.bucketIncomePerSecond,
                                buckets: buckets
                            )
                            .padding(.horizontal)
                        }
                        
                        Spacer().frame(height: 100)
                    }
                    .onChange(of: foregroundHidden) { _ in
                        if foregroundHidden {
                            withAnimation {
                                proxy.scrollTo(0, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $isAddingNewBucket) {
            EditBucketView(
                bucket: Bucket(name: "", targetAmount: 150, income: 100 / secondsPerMonth, whenFinished: .waitToDump, recur: nil),
                save: { newBucket in
                    appData = appData.addBucket(newBucket)
                }
            )
        }
        .onChange(of: foregroundHidden, perform: {newForegroundHidden in spacing = foregroundHidden ? 60 : 30})
        .animation(.spring(), value: spacing)
    }
}

struct AddBucketButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 50)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 50)
                    .stroke(Color.primary.opacity(configuration.isPressed ? 0.3 : 1), lineWidth: 1)
            )
            .foregroundColor(Color.primary.opacity(configuration.isPressed ? 0.3 : 1))
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}


#Preview {
    BackgroundView(
        appData: .constant(AppData(
            monthlyRate: 1000,
            startDate: Date().startOfDay,
            events: [
                .spend(Spend(name: "7/11", amount: 30)),
            ]
        )),
        onSettingsTapped: {},
        foregroundShowingOffset: UIScreen.main.bounds.height / 5,
        foregroundHidden: true,
        currentTime: Date()
    )
}
