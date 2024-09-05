import SwiftUI

struct BudgetAllocationView: View {
    let totalIncomePerSecond: Double
    let bucketIncomePerSecond: Double
    let buckets: [(
        id: UUID,
        amount: Double,
        bucket: Bucket
    )]
    
    private var monthlyTotalIncome: Double {
        totalIncomePerSecond * secondsPerMonth
    }
    
    private var monthlyBucketIncome: Double {
        bucketIncomePerSecond * secondsPerMonth
    }
    
    private var monthlyMainBalance: Double {
        monthlyTotalIncome - monthlyBucketIncome
    }
    
    private var allocationPercentage: Double {
        (monthlyBucketIncome / monthlyTotalIncome) * 100
    }
    
    private var isOverBudget: Bool {
        monthlyBucketIncome > monthlyTotalIncome
    }
    
    
    var body: some View {
        let buckets = buckets.sorted(by: {a, b in a.bucket.income > b.bucket.income})
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                IncomeRow(label: "Total Monthly Income:", amount: monthlyTotalIncome, font: .headline, fontWeight: .bold)
                
                VStack(alignment: .leading, spacing: 8) {
                    IncomeRow(label: "Main Balance:", amount: monthlyMainBalance, font: .headline, indentLevel: 1)
                    IncomeRow(label: "Buckets:", amount: monthlyBucketIncome, font: .headline, indentLevel: 1)
                    
                    // Per-bucket breakdown
                    ForEach(buckets, id: \.id) { bucket in
                        IncomeRow(
                            label: bucket.bucket.name,
                            amount: bucket.bucket.income * secondsPerMonth,
                            font: .subheadline,
                            indentLevel: 2
                        )
                    }
                }
                .padding(.leading)
            }
            
            Text("\(allocationPercentage, specifier: "%.1f")% of income allocated to buckets")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if isOverBudget {
                Text("⚠️ Bucket allocation exceeds total income!")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
        .padding()
        .cornerRadius(10)
    }
}

struct IncomeRow: View {
    let label: String
    let amount: Double
    var font: Font
    var fontWeight: Font.Weight = .regular
    var indentLevel: Int = 0
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                if indentLevel > 0 {
                    ForEach(0..<(indentLevel - 1), id: \.self) { _ in
                        Text(" ")
                            .foregroundColor(.secondary)
                            .frame(width: 10)
                    }
                }
                if indentLevel > 0 {
                    Text("⤷")
                        .foregroundColor(.secondary)
                        .frame(width: 10)
                }
                Text(label)
            }
            .font(font)
            
            Spacer()
            
            Text(formatCurrencyNoDecimals(amount))
                .font(font)
                .fontWeight(fontWeight)
                .monospacedDigit()
        }
    }
}

// Preview
struct BudgetAllocationView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            BudgetAllocationView(totalIncomePerSecond: 0.001157, bucketIncomePerSecond: 0.000694, buckets: [])
            BudgetAllocationView(totalIncomePerSecond: 0.001157, bucketIncomePerSecond: 0.001300, buckets: []) // Over budget example
        }
        .padding()
    }
}
