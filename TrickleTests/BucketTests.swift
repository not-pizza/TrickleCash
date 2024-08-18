import Foundation
import XCTest
@testable import Trickle

class BucketTests: XCTestCase {
    var appData: AppData!
    
    override func setUp() {
        super.setUp()
        appData = AppData(
            monthlyRate: 3000,
            startDate: Date(),
            events: []
        )
    }
    
    override func tearDown() {
        appData = nil
        super.tearDown()
    }
    
    func testBasicIncome() {
        let oneMonthLater = Calendar.current.date(byAdding: .second, value: Int(secondsPerMonth), to: appData.startDate)!
        
        appData.events = [
        ]
        
        let result = appData.calculateTotalIncome(asOf: oneMonthLater)
        
        XCTAssertEqual(result.mainBalance, 3000, accuracy: 0.01)
        XCTAssertTrue(result.buckets.isEmpty)
    }
    
    func testBucketCreation() {
        let oneMonthLater = Calendar.current.date(byAdding: .second, value: Int(secondsPerMonth), to: appData.startDate)!
        
        let bucket = Bucket(name: "Savings", targetAmount: 1000, income: 500 / secondsPerMonth, whenFinished: .waitToDump, recur: nil)
        
        appData.events = [
            .addBucket(AddBucket(dateAdded: appData.startDate, bucketToAdd: bucket))
        ]
        
        let result = appData.calculateTotalIncome(asOf: oneMonthLater)
        
        XCTAssertEqual(result.mainBalance, 2500, accuracy: 0.01)
        XCTAssertEqual(result.buckets.count, 1)
        XCTAssertEqual(result.buckets[0].amount, 500, accuracy: 0.01)
    }
    
    func testBucketDumping() {
        let threeMonthsLater = Calendar.current.date(byAdding: .second, value: Int(secondsPerMonth * 3), to: appData.startDate)!
        
        let bucket = Bucket(name: "Savings", targetAmount: 500, income: 500 / secondsPerMonth / 3, whenFinished: .waitToDump, recur: nil)
        
        let addBucketEvent = AddBucket(dateAdded: appData.startDate, bucketToAdd: bucket)
        appData.events = [
            .addBucket(addBucketEvent)
        ]
        let result = appData.calculateTotalIncome(asOf: threeMonthsLater)
        XCTAssertEqual(result.mainBalance, 8500, accuracy: 0.01) // 9000 - 500
        XCTAssertEqual(result.buckets.count, 1)
        XCTAssertEqual(result.buckets[0].amount, 500, accuracy: 0.01) // Bucket should be full
        
        appData.events = [
            .addBucket(addBucketEvent),
            .dumpBucket(DumpBucket(dateAdded: threeMonthsLater, bucketToDump: addBucketEvent.id))
        ]
        let result2 = appData.calculateTotalIncome(asOf: threeMonthsLater)
        XCTAssertEqual(result2.mainBalance, 9000, accuracy: 0.01) // 9000 - 500 + 500
        XCTAssertEqual(result2.buckets.count, 0)
    }
    
    func testBucketDumpDoesntRemoveRecuringBucket() {
        let oneMonthLater = Calendar.current.date(byAdding: .second, value: Int(secondsPerMonth), to: appData.startDate)!
        let twoMonthsLater = Calendar.current.date(byAdding: .second, value: Int(secondsPerMonth * 2), to: appData.startDate)!
        let threeMonthsLater = Calendar.current.date(byAdding: .second, value: Int(secondsPerMonth * 3), to: appData.startDate)!
        
        let bucket = Bucket(name: "Savings", targetAmount: 300, income: 300 / (secondsPerMonth * (3/2)), whenFinished: .waitToDump, recur: secondsPerMonth * (3/2))
        
        let addBucketEvent = AddBucket(dateAdded: oneMonthLater, bucketToAdd: bucket)
        appData.events = [
            .addBucket(addBucketEvent),
        ]
        
        let result1 = appData.calculateTotalIncome(asOf: twoMonthsLater)
        XCTAssertEqual(result1.buckets.count, 1)
        XCTAssertEqual(result1.mainBalance + result1.buckets[0].amount, 6000, accuracy: 0.01) // We should have made 6000 over 2 months
        XCTAssertEqual(result1.buckets[0].amount, 200, accuracy: 0.01)
        
        appData.events = [
            .addBucket(addBucketEvent),
            .dumpBucket(DumpBucket(dateAdded: twoMonthsLater, bucketToDump: addBucketEvent.id))
        ]
        
        let result2 = appData.calculateTotalIncome(asOf: threeMonthsLater)
        XCTAssertEqual(result2.mainBalance + result2.buckets[0].amount, 9000, accuracy: 0.01) // We should have made 9000 over 4 months
        XCTAssertEqual(result2.mainBalance, 8800, accuracy: 0.01) // 9000 - 100 that went into the new bucket
        XCTAssertEqual(result2.buckets.count, 1)
        XCTAssertEqual(result2.buckets[0].amount, 200, accuracy: 0.01) // New bucket filling up again
    }

    func testRecurringBucketRefillsEvenWithoutEvent() {
        let oneMonthLater = Calendar.current.date(byAdding: .second, value: Int(secondsPerMonth), to: appData.startDate)!
        let oneMonthLaterMinusOneSecond = Calendar.current.date(byAdding: .second, value: Int(secondsPerMonth - 1), to: appData.startDate)!
        
        let bucket = Bucket(name: "Savings", targetAmount: 300, income: 300 / secondsPerMonth, whenFinished: .autoDump, recur: secondsPerMonth)
        
        appData.events = [
            .addBucket(AddBucket(dateAdded: appData.startDate, bucketToAdd: bucket)),
        ]
        
        do {
            let result = appData.calculateTotalIncome(asOf: oneMonthLaterMinusOneSecond)
            XCTAssertEqual(result.buckets.count, 1)
            XCTAssertEqual(result.mainBalance + result.buckets[0].amount, 3000, accuracy: 0.01)
            
            // The bucket hasn't recurred yet so it hasn't gotten added to the main balance
            XCTAssertEqual(result.mainBalance, 2700, accuracy: 0.01)
            XCTAssertEqual(result.buckets[0].amount, 300, accuracy: 0.01)
        }
        
        do {
            let result = appData.calculateTotalIncome(asOf: oneMonthLater + 1)
            XCTAssertEqual(result.buckets.count, 1)
            XCTAssertEqual(result.mainBalance + result.buckets[0].amount, 3000, accuracy: 0.01)
            
            // The bucket just recurred
            XCTAssertEqual(result.mainBalance, 3000, accuracy: 0.01)
            XCTAssertEqual(result.buckets[0].amount, 0, accuracy: 0.01)
        }
    }
    
    func testMultipleBuckets() {
        let oneMonthLater = Calendar.current.date(byAdding: .second, value: Int(secondsPerMonth), to: appData.startDate)!

        let bucket1 = Bucket(name: "Savings", targetAmount: 1000, income: 500 / secondsPerMonth, whenFinished: .waitToDump, recur: nil)
        let bucket2 = Bucket(name: "Emergency Fund", targetAmount: 500, income: 250 / secondsPerMonth, whenFinished: .waitToDump, recur: nil)
        
        appData.events = [
            .addBucket(AddBucket(dateAdded: appData.startDate, bucketToAdd: bucket1)),
            .addBucket(AddBucket(dateAdded: appData.startDate, bucketToAdd: bucket2))
        ]
        
        let result = appData.calculateTotalIncome(asOf: oneMonthLater)
        
        XCTAssertEqual(result.mainBalance, 2250, accuracy: 0.01)
        XCTAssertEqual(result.buckets.count, 2)
        XCTAssertEqual(result.buckets[0].amount, 500, accuracy: 0.01)
        XCTAssertEqual(result.buckets[1].amount, 250, accuracy: 0.01)
    }
    
    func testExcessBucketIncome() {
        let oneMonthLater = Calendar.current.date(byAdding: .second, value: Int(secondsPerMonth), to: appData.startDate)!
        let twoMonthsLater = Calendar.current.date(byAdding: .second, value: Int(secondsPerMonth * 2), to: appData.startDate)!

        // Create buckets with combined income greater than monthly rate
        let bucket1 = Bucket(name: "Savings", targetAmount: 2000, income: 2000 / secondsPerMonth, whenFinished: .waitToDump, recur: nil)
        let bucket2 = Bucket(name: "Emergency Fund", targetAmount: 1500, income: 1500 / secondsPerMonth, whenFinished: .waitToDump, recur: nil)
        
        appData.events = [
            .addBucket(AddBucket(dateAdded: appData.startDate, bucketToAdd: bucket1)),
            .addBucket(AddBucket(dateAdded: appData.startDate, bucketToAdd: bucket2))
        ]
        
        // Check after one month
        let result1 = appData.calculateTotalIncome(asOf: oneMonthLater)
        
        XCTAssertEqual(result1.mainBalance, -500, accuracy: 0.01)
        XCTAssertEqual(result1.buckets.count, 2)
        XCTAssertEqual(Set(result1.buckets.map({i in i.amount.rounded()})), [2000, 1500])
        XCTAssertEqual(result1.mainBalance + result1.buckets.reduce(0) {acc, i in acc + i.amount}, 3000, accuracy: 0.01)
        
        // Check after two months
        let result2 = appData.calculateTotalIncome(asOf: twoMonthsLater)
        
        XCTAssertEqual(result2.mainBalance, 6000 - 3500, accuracy: 0.01)
        XCTAssertEqual(result2.buckets.count, 2)
        XCTAssertEqual(Set(result1.buckets.map({i in i.amount.rounded()})), [2000, 1500])
        XCTAssertEqual(result2.mainBalance + result2.buckets.reduce(0) {acc, i in acc + i.amount}, 6000, accuracy: 0.01)
    }
}
