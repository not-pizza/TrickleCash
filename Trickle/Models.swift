import Foundation
import Oklab
import WidgetKit
import SwiftUI

struct AppData: Codable, Equatable {
    var monthlyRate: Double
    var startDate: Date
    var events: [Event]
    
    init(monthlyRate: Double, startDate: Date, events: [Event]) {
        self.monthlyRate = monthlyRate
        self.startDate = startDate
        self.events = events
    }
    
    func getMonthlyRate(asOf date: Date = Date()) -> Double {
        let relevantEvents = events.filter { event in
            if case .setMonthlyRate(let rateEvent) = event, rateEvent.dateAdded <= date {
                return true
            }
            return false
        }.sorted { $0.date > $1.date }
        
        if let mostRecentEvent = relevantEvents.first, case .setMonthlyRate(let rateEvent) = mostRecentEvent {
            return rateEvent.rate
        }
        
        return monthlyRate
    }
    
    func getDailyRate(asOf date: Date = Date()) -> Double {
        let monthlyRate = getMonthlyRate(asOf: date);
        return monthlyRate * 12 / 365
    }
    
    func getStartDate(asOf date: Date = Date()) -> Date {
        let relevantEvents = events.filter { event in
            if case .setStartDate(let startDateEvent) = event, startDateEvent.dateAdded <= date {
                return true
            }
            return false
        }.sorted { $0.date > $1.date }
        
        if let mostRecentEvent = relevantEvents.first, case .setStartDate(let startDateEvent) = mostRecentEvent {
            return startDateEvent.startDate
        }
        
        return startDate
    }
    
    func getTrickleBalance(asOf time: Date) -> Double {
        let totalIncome = self.calculateTotalIncome(asOf: time);
        
        let spendEvents = self.getSpendEventsAfterStartDate(asOf: time);
        let totalDeductions = spendEvents.map({spend in spend.amount}).reduce(0, +)
        
        return totalIncome.mainBalance - totalDeductions + 0.01
    }
    
    func getPercentThroughCurrentCent(time: Date) -> Double {
        let balance = getTrickleBalance(asOf: time)
        var percent = (balance - 0.005).truncatingRemainder(dividingBy: 0.01) * 100
        if balance < 0 {
            percent = 1 + percent
        }
        return percent
    }
    
    func addSpend(_ spend: Spend) -> Self {
        var events = self.events
        events.append(.spend(spend))
        return Self(monthlyRate: self.monthlyRate, startDate: self.startDate, events: events)
    }
    
    func updateSpend(_ spend: Spend) -> Self {
        self.updateEvent(newEvent: .spend(spend))
    }
    
    func updateEvent(newEvent: Event) -> Self {
        let events = self.events.map({event in
            if event.id == newEvent.id {
                newEvent
            }
            else {
                event
            }
        })
        return Self(monthlyRate: self.monthlyRate, startDate: self.startDate, events: events)
    }
    
    func setMonthlyRate(_ rate: SetMonthlyRate) -> Self {
        var events = self.events
        events.append(.setMonthlyRate(rate))
        return Self(monthlyRate: self.monthlyRate, startDate: self.startDate, events: events)
    }
    
    func setStartDate(_ startDate: SetStartDate) -> Self {
        var events = self.events
        events.append(.setStartDate(startDate))
        return Self(monthlyRate: self.monthlyRate, startDate: self.startDate, events: events)
    }
    
    func deleteEvent(id: UUID) -> Self {
        var events = self.events
        events.removeAll { $0.id == id }
        return Self(monthlyRate: monthlyRate, startDate: startDate, events: events)
    }
    
    func getSpendEventsAfterStartDate(asOf date: Date = Date()) -> [Spend] {
        let currentStartDate = getStartDate(asOf: date)
        return events.compactMap { event in
            if case .spend(let spend) = event, spend.dateAdded > currentStartDate && spend.dateAdded <= date {
                return spend
            }
            return nil
        }
    }
    
    func save() -> Self {
        if let defaults = UserDefaults(suiteName: "group.pizza.not.Trickle") {
            let updatableAppData = UpdatableAppData.v1(self)
            if let encoded = try? JSONEncoder().encode(updatableAppData) {
                defaults.set(encoded, forKey: "AppData")
                print("saved app data")
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        else {
            print("couldn't save app data")
        }
        return self
    }
    
    static func load() -> Self? {
        if let defaults = UserDefaults(suiteName: "group.pizza.not.Trickle") {
            if let savedData = defaults.data(forKey: "AppData"),
               let decodedData = try? JSONDecoder().decode(UpdatableAppData.self, from: savedData) {
                return decodedData.appData
            }
        }
        // Return default values
        return nil
    }
    
    static func loadOrDefault() -> Self {
        if let defaults = UserDefaults(suiteName: "group.pizza.not.Trickle") {
            if let savedData = defaults.data(forKey: "AppData"),
               let decodedData = try? JSONDecoder().decode(UpdatableAppData.self, from: savedData) {
                return decodedData.appData
            }
        }
        // Return default values
        return Self(
            monthlyRate: 1000.0,
            startDate: Date(),
            events: []
        )
    }
    
    // TODO: replace `perSecondRate` with `timeToCompletion`
    func calculateTotalIncome(asOf date: Date = Date()) -> (mainBalance: Double, buckets: [(bucket: Bucket, amount: Double, perSecondRate: Double)]) {
        let startDate = getStartDate(asOf: date)
        var currentPerSecondRate = monthlyRate / secondsPerMonth
        var lastEventDate = startDate
        var buckets: [UUID: Bucket] = [:]
        var bucketInfo: [UUID: (amount: Double, perSecondRate: Double)] = [:]
        var mainBalance = 0.0
        
        // Sort events by date
        let sortedEvents = events.filter { $0.date <= date }.sorted { $0.date < $1.date }
        let filteredEvents = Event.removeDeleted(sortedEvents)
        
        for event in filteredEvents {
            // Calculate income up to this event change
            let secondsAtCurrentRate = event.date.timeIntervalSince(lastEventDate)
            let incomeForPeriod = currentPerSecondRate * secondsAtCurrentRate
            distributeToBuckets(amount: incomeForPeriod, duration: secondsAtCurrentRate)
            handleFinishedBuckets()
            
            switch event {
            case .setMonthlyRate(let setMonthlyRate):
                // Update rate and last change date
                currentPerSecondRate = setMonthlyRate.rate / secondsPerMonth
                
            case .addBucket(let addBucket):
                buckets[addBucket.id] = addBucket.bucketToAdd
                bucketInfo[addBucket.id] = (0.0, 0.0)
                
            case .updateBucket(let update):
                if buckets[update.bucketToUpdate] != nil {
                    buckets[update.bucketToUpdate] = update.newBucket
                }
                
            case .deleteBucket(_):
                fatalError("Encountered a .deleteBucket event - should never happen")
                
            case .dumpBucket(let dumpBucket):
                if let bucket = buckets[dumpBucket.bucketToDump]
                {
                    if bucket.allowsDump {
                        mainBalance += bucketInfo[dumpBucket.bucketToDump]!.amount
                        bucketInfo[dumpBucket.bucketToDump]!.amount = 0
                        if !bucket.recur {
                            bucketInfo.removeValue(forKey: dumpBucket.bucketToDump)
                            buckets.removeValue(forKey: dumpBucket.bucketToDump)
                        }
                    }
                }
                
            case .setStartDate, .spend:
                // These events don't affect income calculation
                break
            }
            
            lastEventDate = event.date
        }
        
        // Calculate income from last rate change to the specified date
        let secondsAtCurrentRate = date.timeIntervalSince(lastEventDate)
        let finalIncomeForPeriod = currentPerSecondRate * secondsAtCurrentRate
        distributeToBuckets(amount: finalIncomeForPeriod, duration: secondsAtCurrentRate)
        handleFinishedBuckets()
        
        // Prepare the result
        let bucketResults = buckets.map { (id, bucket) in
            (bucket: bucket, amount: bucketInfo[id]?.amount ?? 0.0, perSecondRate: bucketInfo[id]?.perSecondRate ?? 0.0)
        }
        
        return (mainBalance: mainBalance, buckets: bucketResults)
        
        func distributeToBuckets(amount: Double, duration: TimeInterval) {
            var remainingAmount = amount
            
            // First, handle byDuration buckets
            // As they have priority over the main balance and the share buckets
            do {
                let byDurationBuckets: [(UUID, Bucket)] = Array(buckets.filter { (_, bucket) in
                    if case .byDuration = bucket.contributionMode { return true }
                    return false
                })
                let totalByDurationPerSecondRate = byDurationBuckets.reduce(0.0) { sum, bucket in
                    let (_, bucket) = bucket
                    if case .byDuration(_, let interval) = bucket.contributionMode {
                        return sum + (bucket.targetAmount / Double(interval))
                    }
                    return sum
                }
                let amountToDistributeToByDurationBuckets = min(amount, totalByDurationPerSecondRate * duration)
                let byDurationDistributees = byDurationBuckets.map({(id, bucket) in
                    guard case .byDuration(_, let interval) = bucket.contributionMode else {
                        fatalError("This should never happen")
                    }
                    let share = bucket.targetAmount / Double(interval)
                    return Distributee(cap: (bucket.targetAmount - bucketInfo[id]!.amount) as Double?, share: share)
                })
                
                let byDurationBucketDistributions = DistributionSequence.distribute(amount: amountToDistributeToByDurationBuckets, distributees: byDurationDistributees)
                remainingAmount = max(amount - amountToDistributeToByDurationBuckets + byDurationBucketDistributions.remainder, 0) // Shouldn't be less than 0 according to math, but sometimes floating point arithmetic thinks differently
                
                for (index, distribution) in byDurationBucketDistributions.distributions.enumerated() {
                    let (id, bucket) = byDurationBuckets[index]
                    let info = bucketInfo[id]!
                    let newAmount = info.amount + distribution.cumulativeAmount
                    let newPerSecondRate = distribution.cumulativeAmount / duration
                    bucketInfo[id] = (newAmount, newPerSecondRate)
                }
            }
            
            // Then, handle share buckets and main balance
            do {
                let shareBuckets = Array(buckets.filter { (_, bucket) in
                    if case .share = bucket.contributionMode { return true }
                    return false
                })
                var shareDistributees = shareBuckets.map({(id, bucket) in
                    guard case .share(let share) = bucket.contributionMode else {
                        fatalError("This should never happen")
                    }
                    return Distributee(cap: (bucket.targetAmount - bucketInfo[id]!.amount) as Double?, share: share)
                })
                
                // Reserve the first share distribution for the main balance
                shareDistributees.insert(Distributee(cap: nil as Double?, share: 10), at: 0)
                let shareBucketDistributions = DistributionSequence.distribute(amount: remainingAmount, distributees: shareDistributees)
                
                for (index, distribution) in shareBucketDistributions.distributions[1...].enumerated() {
                    let (id, bucket) = shareBuckets[index]
                    let info = bucketInfo[id]!
                    let newAmount = info.amount + distribution.cumulativeAmount
                    let newPerSecondRate = distribution.cumulativeAmount / duration
                    bucketInfo[id] = (newAmount, newPerSecondRate)
                }
                
                // Remaining amount goes to main balance
                mainBalance += shareBucketDistributions.distributions[0].cumulativeAmount
            }
        }
        
        func handleFinishedBuckets() {
            buckets = Dictionary(uniqueKeysWithValues: buckets.compactMap({(id, bucket) in
                let onFinish = finishBucketIfNecessary(id, bucket)
                if let onFinish = onFinish {
                    switch onFinish {
                    case .replace(let bucket):
                        bucketInfo[id] = (0.0, 0.0)
                        return (id, bucket)
                    case .delete:
                        bucketInfo.removeValue(forKey: id)
                        return nil
                    }
                }
                // Bucket isn't finished yet, don't do anything to it
                else {
                    return (id, bucket)
                }
            }))
        }
        
        enum BucketFinished {
            case replace(Bucket)
            case delete
        }
        
        // Returns true if we should keep the bucket
        // TODO: take the current time and return the time the bucket finished as well (only different for .byDuration buckets)
        func finishBucketIfNecessary(_ id: UUID, _ bucket: (Bucket)) -> BucketFinished? {
            if bucketInfo[id]!.amount >= bucket.targetAmount /* TODO: .byDuration buckets should only be finished if the date is after their startTime+duration */
            {
                switch bucket.whenFinished {
                    
                case .waitToDump:
                    // waitToDump buckets are always finished manually
                    return nil
                case .autoDump:
                    mainBalance += bucketInfo[id]!.amount
                case .destroy:
                    break
                }
                
                if bucket.recur {
                    // TODO: if this is a bucket whose ContributionMode is .byDuration(let interval), replace with a bucket whose dateAdded has been moved up the minimum number of `interval`s to make its dateAdded + interval be in the future
                    return .replace(bucket)
                }
                else {
                    return .delete
                }
            }
            else {
                return nil
            }
        }
    }
}

struct SetMonthlyRate: Codable, Equatable, Identifiable {
    var rate: Double
    var dateAdded: Date = Date()
    var id: UUID = UUID()
    
    var description: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "SetMonthlyRate(rate: $\(String(format: "%.2f", rate)))"
    }
}

struct SetStartDate: Codable, Equatable, Identifiable {
    var startDate: Date
    var dateAdded: Date = Date()
    var id: UUID = UUID()
    
    var description: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "SetStartDate(startDate: \(formatter.string(from: startDate)))"
    }
}

struct Spend: Identifiable, Codable, Equatable {
    enum AddedFrom : Codable, Equatable {
        case shortcut
    }
    
    var id: UUID = UUID()
    var name: String
    var merchant: String?
    var paymentMethod: String?
    var amount: Double
    var dateAdded: Date = Date()
    
    // If unset, it means it was added by the app
    var addedFrom: AddedFrom?
    
    var description: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Spend(amount: $\(String(format: "%.2f", amount)), name: \"$\(name)\""
    }
}

enum Event: Codable, Identifiable, Equatable {
    case spend(Spend)
    case setMonthlyRate(SetMonthlyRate)
    case setStartDate(SetStartDate)
    
    case addBucket(AddBucket)
    case updateBucket(UpdateBucket)
    case dumpBucket(DumpBucket)
    case deleteBucket(DeleteBucket)
    
    var id: UUID {
        switch self {
        case .spend(let spend):
            return spend.id
        case .setMonthlyRate(let setMonthlyRate):
            return setMonthlyRate.id
        case .setStartDate(let setStartDate):
            return setStartDate.id
        case .addBucket(let addBucket):
            return addBucket.id
        case .updateBucket(let updateBucket):
            return updateBucket.id
        case .dumpBucket(let dumpBucket):
            return dumpBucket.id
        case .deleteBucket(let deleteBucket):
            return deleteBucket.id
        }
    }
    
    var date: Date {
        switch self {
        case .spend(let spend):
            return spend.dateAdded
        case .setMonthlyRate(let event):
            return event.dateAdded
        case .setStartDate(let event):
            return event.dateAdded
        case .addBucket(let bucket):
            return bucket.dateAdded
        case .updateBucket(let updateBucket):
            return updateBucket.dateAdded
        case .dumpBucket(let dumpBucket):
            return dumpBucket.dateAdded
        case .deleteBucket(let deleteBucket):
            return deleteBucket.dateAdded
        }
    }
    
    static func removeDeleted(_ events: [Event]) -> [Event] {
        var deletedBucketIDs = Set<UUID>()
        var filteredEvents = [Event]()

        // First pass: Identify deleted buckets
        for event in events {
            if case let .deleteBucket(deleteBucket) = event {
                deletedBucketIDs.insert(deleteBucket.bucketToDelete)
            }
        }

        // Second pass: Filter out events related to deleted buckets
        for event in events {
            switch event {
            case .addBucket(let bucket):
                if !deletedBucketIDs.contains(bucket.id) {
                    filteredEvents.append(event)
                }
            case .updateBucket(let updateBucket):
                if !deletedBucketIDs.contains(updateBucket.bucketToUpdate) {
                    filteredEvents.append(event)
                }
            case .dumpBucket(let dumpBucket):
                if !deletedBucketIDs.contains(dumpBucket.bucketToDump) {
                    filteredEvents.append(event)
                }
            case .deleteBucket:
                // Remove deleteBucket events
                break
            case .spend, .setMonthlyRate, .setStartDate:
                // Keep other events
                filteredEvents.append(event)
            }
        }

        return filteredEvents
    }

}

// Buckets
struct AddBucket: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var dateAdded: Date = Date()
    
    let bucketToAdd: Bucket
}

struct UpdateBucket: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var dateAdded: Date = Date()
    
    let bucketToUpdate: UUID
    let newBucket: Bucket
}

struct DumpBucket: Codable, Identifiable, Equatable
{
    var id: UUID = UUID()
    var dateAdded: Date = Date()
    
    let bucketToDump: UUID
}

struct DeleteBucket: Codable, Identifiable, Equatable
{
    var id: UUID = UUID()
    var dateAdded: Date = Date()
    
    let bucketToDelete: UUID
}

struct Bucket: Codable, Equatable {
    enum ContributionMode: Codable, Equatable {
        case share(share: Double)
        case byDuration(startDate: Date, interval: TimeInterval)
    }

    enum FinishAction: Codable, Equatable {
        case waitToDump
        case autoDump
        case destroy
    }

    let name: String
    let targetAmount: Double
    let contributionMode: ContributionMode
    let whenFinished: FinishAction
    let recur: Bool
    
    enum FillMode {
        case loop(Double)
        case max(Double)
        
        var cap: Double {
            switch self {
            case .loop(let d):
                return d
            case .max(let d):
                return d
            }
        }
    }
    
    var allowsDump: Bool {
        switch self.whenFinished {
        case .destroy:
            return false
        case .waitToDump, .autoDump:
            return true
        }
    }
}

// Where all our main app data is stored
enum UpdatableAppData: Codable {
    case v1(AppData)
    
    var appData: AppData {
        switch self {
        case .v1(let data):
            return data
        }
    }
}

struct Distributee {
    var cap: Double?
    let share: Double
}

struct DistributionSequence: Sequence {
    let distributees: [Distributee]
    
    func makeIterator() -> DistributionIterator {
        return DistributionIterator(distributees: distributees)
    }
    
    /*
    this might need to be:
    static func distribute(amount: Double, duration: TimeInterval, distributees: [(fill: FillMode?, starting: TimeInterval, share: Double)])
    -> (
        remainder: Double, /* Any amount that has not been allocated. If any distributee is has a */
        distributions: [(time: TimeInterval, balances: [Double])] /* one entry for every time there is a slope change) */
    ) {
    */
    static func distribute(amount: Double, distributees: [Distributee]) -> (remainder: Double, distributions: [Distribution]) {
        let sequence = DistributionSequence(distributees: distributees)
        let mostRecentSlopeChangeAtAmount = lastTrueElement(
            in: sequence,
            where: {distribution in
                distribution.totalCumulativeDistribution <= amount
        })
        if let mostRecentSlopeChangeAtAmount = mostRecentSlopeChangeAtAmount {
            let newDistributees = distributees - mostRecentSlopeChangeAtAmount
            var finalDistibution = Self(distributees: newDistributees).makeIterator()
            let remainder = finalDistibution.distributeAmount(amount: amount - mostRecentSlopeChangeAtAmount.totalCumulativeDistribution)
            return (remainder, mostRecentSlopeChangeAtAmount.combine(finalDistibution.distributions))
        }
        else {
            var sequence = sequence.makeIterator()
            if let first = sequence.next()
            {
                fatalError("couldn't find an distribution with a cumulative amount less than <= \(amount) in [\(String(describing: first)), ...]")
            }
            else {
                fatalError("distribution sequence has no elements!")
            }
        }
    }
}

struct DistributionIterator: IteratorProtocol {
    let distributees: [Distributee]
    
    var remainingDistributees: [(index: Int, cap: Double?, share: Double)]
    var distributions: [Distribution]
    var hitInitialDistribution: Bool = false
    var hitFinalDistribution: Bool = false
    
    var remainingShares: Double {
        return self.remainingDistributees.reduce(0) { acc, distributee in
            acc + distributee.share
        }
    }
    
    init(distributees: [Distributee]) {
        self.distributees = distributees
        self.remainingDistributees = distributees.enumerated().map { (index: $0, cap: $1.cap, share: $1.share) }.filter({ $0.cap != 0 })
        
        let totalShares = self.remainingDistributees.reduce(0) { $0 + $1.share }
        self.distributions = distributees.map({distributee in Distribution(distributions: [], fractionOfTotal: distributee.share/totalShares)})
    }

    // Returns the remainder if we get capped
    // Will only attempt to distribute "once", and will stop as soon as one gets capped
    fileprivate mutating func distributeAmount(amount: Double) -> Double {
        var totalToDistribute = amount
        var amountDistributed = 0.0
        let cappedDistributees = remainingDistributees.compactMap({distribution in
            if let cap = distribution.cap {
                return (
                    index: distribution.index,
                    remaining: cap - distributions[distribution.index].cumulativeAmount,
                    share: distribution.share
                )
            } else {
                return nil
            }
        })
        if let soonestCap = cappedDistributees.min(by: {
            ($0.remaining) / $0.share < ($1.remaining) / $1.share })
        {
            totalToDistribute = min(totalToDistribute, soonestCap.remaining / (soonestCap.share / Double(remainingShares)))
        }
        
        self.remainingDistributees = self.remainingDistributees.filter { distributee in
            let remainingShares = self.remainingShares
            let amountPerShare = totalToDistribute / remainingShares
            let toDistributee = distributee.share * amountPerShare
            
            if let cap = distributee.cap {
                let remainingCap = cap - self.distributions[distributee.index].cumulativeAmount
                // Has to be less than or equal to the remaining cap or the caller messed up
                let toDistributee = min(remainingCap, toDistributee)
                assert(toDistributee <= remainingCap + 0.0001)
                amountDistributed += toDistributee
                let capped = toDistributee >= remainingCap - 0.0001
                self.distributions[distributee.index].add(
                    amount: toDistributee
                )
                
                return !capped
            } else {
                amountDistributed += toDistributee
                self.distributions[distributee.index].add(amount: toDistributee)
                
                return true
            }
        }
        return amount - amountDistributed
    }
    
    mutating func next() -> [Distribution]? {
        guard hitInitialDistribution else {
            hitInitialDistribution = true
            return distributions
        }
        guard !hitFinalDistribution else { return nil }
        guard !self.remainingDistributees.isEmpty else { return nil }
        
        let remainingShares = self.remainingShares
        
        // Compute the maximum we can distribute before the next time the slope changes
        if remainingDistributees.contains(where: {$0.cap != nil})
        {
            let toDistributeThisRound = distributees.amountToSaturateCapped
            let _ = distributeAmount(amount: toDistributeThisRound)
        }
        else
        {
            // no capped distributions remaining
            hitFinalDistribution = true
            for (index, _, _) in remainingDistributees {
                self.distributions[index].add(amount: 0)
            }
        }

        
        return self.distributions
    }
}

struct Distribution: Equatable {
    var distributions: [Double]
    
    // TODO: replace with extracted Neumaier sum function
    var cumulativeAmount: Double {
        var sum = 0.0
        var c = 0.0  // A running compensation for lost low-order bits.
        
        for distribution in distributions {
            let y = distribution - c
            let t = sum + y
            c = (t - sum) - y
            sum = t
        }
        
        return sum
    }
    
    init(distributions: [Double] = [], fractionOfTotal: Double = 0.0) {
        self.distributions = distributions
    }
    
    mutating func add(amount: Double) {
        self.distributions.append(amount)
    }
}

extension [Distribution] {
    // TODO: use Neumaier sum
    var totalCumulativeDistribution: Double {
        return self.reduce(0) { $0 + $1.cumulativeAmount }
    }
}

func lastTrueElement<S: Sequence>(
    in sequence: S,
    where predicate: (S.Element) -> Bool
) -> S.Element? {
    var lastTrue: S.Element?
    
    for element in sequence {
        if predicate(element) {
            lastTrue = element
        } else {
            break
        }
    }
    
    return lastTrue
}


extension Array where Element == Distribution {
    func combine(_ distributions2: [Distribution]) -> [Distribution] {
        return self.enumerated().map { (index, d1) in
            let d2 = distributions2[index]
            return Distribution(distributions: d1.distributions + d2.distributions)
        }
    }
}

extension Array where Element == Distributee {
    static func - (distributees: [Distributee], distributions: [Distribution]) -> [Distributee] {
        return distributees.enumerated().map { (index, distributee) in
            let distribution = distributions[index]
            var newDistributee = distributee
            newDistributee.removeDistribution(distribution)
            return newDistributee
        }
    }
    
    var amountToSaturateCapped: Double {
        let totalShares = self.reduce(0) { acc, distributee in
            acc + distributee.share
        }
        let maxCap = self.compactMap({distributee in
            if let cap = distributee.cap {
                return (
                    cap: cap,
                    share: distributee.share
                )
            } else {
                return nil
            }
        }).max(by: {
            ($0.cap) / $0.share < ($1.cap) / $1.share })
        if let maxCap = maxCap {
            return maxCap.cap / (maxCap.share / Double(totalShares))
        }
        else {
            return 0
        }
    }
}

// Extension to Distributee to handle removal of a Distribution
extension Distributee {
    mutating func removeDistribution(_ distribution: Distribution) {
        if self.cap != nil {
            self.cap = self.cap! - distribution.cumulativeAmount
        }
    }
}
