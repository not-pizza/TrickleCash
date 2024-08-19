import SwiftUI

struct BucketView: View {
    let id: UUID
    let amount: Double
    @Binding var bucket: Bucket
    let currentTime: Date
    
    @State private var animationProgress: CGFloat = 0
    @State private var isEditingBucket = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(bucket.name)
                    .font(.headline)
                Spacer()
                Text(String(format: "$%.2f / $%.2f", amount, bucket.targetAmount))
                    .font(.subheadline)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: geometry.size.width * animationProgress, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
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
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animationProgress = CGFloat(amount / bucket.targetAmount)
            }
        }
        .contextMenu {
            Button("Dump into Trickle") {
                print("dump selected")
            }
            Button("Edit") {
                isEditingBucket = true
            }
        }
        .sheet(isPresented: $isEditingBucket) {
            EditBucketView(bucket: $bucket)
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
            return "Wait to dump"
        case .autoDump:
            return "Auto dump"
        case .destroy:
            return "Destroy when finished"
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
                    currentTime: Date()
                )
            }
        }
    }
}
