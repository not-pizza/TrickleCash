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
    
    func calculateTotalIncome(asOf date: Date = Date()) -> (mainBalance: Double, buckets: [(bucket: Bucket, amount: Double)]) {
        let startDate = getStartDate(asOf: date)
        var currentPerSecondRate = monthlyRate / secondsPerMonth
        var lastEventDate = startDate
        var buckets: [UUID: (bucket: Bucket, amount: Double)] = [:]
        var mainBalance = 0.0
        
        // Sort events by date
        let sortedEvents = events.filter { $0.date <= date }.sorted { $0.date < $1.date }
        let filteredEvents = Event.removeDeleted(sortedEvents)
        
        for event in filteredEvents {
            // Calculate income up to this event change
            let secondsAtCurrentRate = event.date.timeIntervalSince(lastEventDate)
            let incomeForPeriod = currentPerSecondRate * secondsAtCurrentRate
            let distributedToBuckets = distributeToBuckets(duration: secondsAtCurrentRate)
            mainBalance += incomeForPeriod - distributedToBuckets
            
            switch event {
            case .setMonthlyRate(let setMonthlyRate):
                // Update rate and last change date
                currentPerSecondRate = setMonthlyRate.rate / secondsPerMonth
                
            case .addBucket(let addBucket):
                buckets[addBucket.id] = (bucket: addBucket.bucketToAdd, amount: 0.0)
                
            case .updateBucket(let update):
                if buckets[update.bucketToUpdate] != nil {
                    buckets[update.bucketToUpdate]!.bucket = update.newBucket
                }
                
            case .deleteBucket(_):
                fatalError("Encountered a .deleteBucket event - should never happen")
                
            case .dumpBucket(let dumpBucket):
                if let (bucket, amount) = buckets[dumpBucket.bucketToDump]
                {
                    let (newBucket, doWithCash) = bucket.dump(dumpingManually: true)
                    switch doWithCash {
                    case .transfer:
                        mainBalance += amount
                        buckets[dumpBucket.bucketToDump]!.amount = 0
                    case .destroy:
                        buckets[dumpBucket.bucketToDump]!.amount = 0
                    case nil:
                        break
                    }
                    
                    if let newBucket = newBucket {
                        buckets[dumpBucket.bucketToDump]!.bucket = newBucket
                    }
                    else {
                        buckets.removeValue(forKey: dumpBucket.bucketToDump)
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
        let incomeForPeriod = currentPerSecondRate * secondsAtCurrentRate
        let distributedToBuckets = distributeToBuckets(duration: secondsAtCurrentRate)
        mainBalance += incomeForPeriod - distributedToBuckets
        
        return (mainBalance: mainBalance, buckets: Array(buckets.values))
        
        func distributeToBuckets(duration: TimeInterval) -> Double {
            var distributed = 0.0
            
            buckets = buckets.compactMapValues { (bucket, previousAmount) in
                var remainingDuration = duration
                var current = (bucket: bucket, amount: previousAmount)
                
                while remainingDuration > 0 {
                    let amountInDuration = current.bucket.income * remainingDuration
                    let amountNeeded = current.bucket.targetAmount - current.amount
                    
                    if amountInDuration <= amountNeeded {
                        // Not enough to fill the bucket
                        current.amount += amountInDuration
                        distributed += amountInDuration
                        remainingDuration = 0
                    } else {
                        // Enough to fill the bucket
                        let timeToFill = amountNeeded / current.bucket.income
                        current.amount = current.bucket.targetAmount
                        distributed += amountNeeded
                        remainingDuration -= timeToFill
                        
                        let (new, doWithCash) = current.bucket.dump(dumpingManually: false)
                        switch doWithCash {
                        case .transfer:
                            mainBalance += current.amount
                            current.amount = 0
                        case .destroy:
                            current.amount = 0
                        case nil:
                            remainingDuration = 0
                            break
                        }
                        
                        if let new = new {
                            return (new, current.amount)
                        }
                        else {
                            return nil
                        }
                    }
                }
                
                return current
            }
            
            return distributed
        }
        enum BucketFinished {
            case replace(Bucket)
            case delete
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
    enum FinishAction: Codable, Equatable {
        case waitToDump
        case autoDump
        case destroy
    }

    let name: String
    let targetAmount: Double
    let income: Double
    let whenFinished: FinishAction
    let recur: TimeInterval?
    
    var allowsDump: Bool {
        switch self.whenFinished {
        case .destroy:
            return false
        case .waitToDump, .autoDump:
            return true
        }
    }
    
    enum DoWithCash {
        case transfer
        case destroy
    }
    
    func dump(dumpingManually: Bool) -> (
        newBucket: Bucket?,
        result: DoWithCash?
    ) {
        var newBucket: Bucket? = nil
        if let recurrancePeriod = self.recur {
            newBucket = Bucket(
                name: self.name,
                targetAmount: self.targetAmount,
                income: self.targetAmount / recurrancePeriod,
                whenFinished: self.whenFinished,
                recur: self.recur
            )
        }
    
        switch (self.whenFinished, dumpingManually) {
        case (.waitToDump, false):
            return (newBucket: self, result: nil)
        case (.waitToDump, true):
            return (newBucket: newBucket, result: .transfer)
        case (.autoDump, _):
            return (newBucket: newBucket, result: .transfer)
        case (.destroy, _):
            return (newBucket: newBucket, result: .destroy)
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
