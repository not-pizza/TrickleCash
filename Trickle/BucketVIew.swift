import SwiftUI

struct BucketView: View {
    let id: UUID
    let amount: Double
    @Binding var bucket: Bucket
    var dump: () -> Void
    var delete: () -> Void
    let currentTime: Date
    
    @State private var animationProgress: CGFloat = 0
    @State private var isEditingBucket = false
    @State private var tempBucket: Bucket
    
    init(id: UUID, amount: Double, bucket: Binding<Bucket>, dump: @escaping () -> Void, delete: @escaping () -> Void, currentTime: Date) {
        self.id = id
        self.amount = amount
        self._bucket = bucket
        self.currentTime = currentTime
        self._tempBucket = State(initialValue: bucket.wrappedValue)
        self.dump = dump
        self.delete = delete
    }
    
    var formatStyle: Date.RelativeFormatStyle {
        var formatStyle = Date.RelativeFormatStyle()
        formatStyle.presentation = .named
        return formatStyle
    }
    
    var body: some View {
        let timeFilled = bucket.estimatedCompletionDate(amount, at: currentTime)
        let filledWhen = timeFilled.formatted(formatStyle)
        
        return Button(action: {isEditingBucket = true}) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(bucket.name.smartCapitalized)
                        .font(.headline)
                    Spacer()
                    Text(String(format: "\(amount == bucket.targetAmount ? "✓ " : "")\(formatCurrencyNoDecimals(floor(amount))) / \(formatCurrencyNoDecimals(bucket.targetAmount))"))
                        .font(.subheadline)
                }
                
                HStack {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 8)
                                .cornerRadius(4)
                            
                            Rectangle()
                                .fill(Color.primary)
                                .frame(width: geometry.size.width * animationProgress * CGFloat(amount / bucket.targetAmount), height: 8)
                                .cornerRadius(4)
                        }
                    }
                    .frame(height: 8)
                    
                    Text(filledWhen.smartCapitalized)
                        .font(.subheadline)
                }
                
                HStack {
                    Text(formatRecurrence(bucket.recur))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatFinishAction(bucket.whenFinished))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .buttonStyle(.plain)
        .background(Color.secondary.opacity(amount == bucket.targetAmount ? 0.3 : 0.1))
        .cornerRadius(10)
        .padding(.horizontal)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animationProgress = 1
            }
        }
        .sheet(isPresented: $isEditingBucket) {
            EditBucketView(
                bucket: bucket,
                amount: amount,
                save: { newBucket in
                    bucket = newBucket
                },
                dump: dump,
                delete: delete
            )
        }
    }
    
    private func formatRecurrence(_ recurrence: TimeInterval?) -> String {
        guard let recurrence = recurrence else { return "One-time" }
        let days = Int(recurrence / (24 * 60 * 60))
        return "Recurs every \(days) day\(days == 1 ? "" : "s")"
    }
    
    private func formatFinishAction(_ action: Bucket.FinishAction) -> String {
        switch action {
        case .waitToDump:
            return ""
        case .autoDump:
            return "Auto dump"
        case .destroy:
            return "Destroy"
        }
    }
}

struct BucketView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            balanceBackgroundGradient(-30, colorScheme: .dark).ignoresSafeArea()
            
            VStack(alignment: .leading) {
                BucketView(
                    id: UUID(),
                    amount: 750,
                    bucket: .constant(Bucket(
                        name: "Vacation Fund",
                        targetAmount: 1000,
                        income: 10 / secondsPerMonth,
                        whenFinished: .autoDump,
                        recur: 30 * 24 * 60 * 60
                    )),
                    dump: {
                        print("dump me :D")
                    },
                    delete: {
                        print("delete me :D")
                    },
                    currentTime: Date()
                )
                BucketView(
                    id: UUID(),
                    amount: 1000,
                    bucket: .constant(Bucket(
                        name: "iPhone",
                        targetAmount: 1000,
                        income: 10 / secondsPerMonth,
                        whenFinished: .autoDump,
                        recur: 30 * 24 * 60 * 60
                    )),
                    dump: {
                        print("dump me :D")
                    },
                    delete: {
                        print("delete me :D")
                    },
                    currentTime: Date()
                )
            }
        }
    }
}
