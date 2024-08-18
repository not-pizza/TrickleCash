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
        
        let bucket = Bucket(name: "Savings", targetAmount: 1000, income: 500 / secondsPerMonth, whenFinished: .waitToDump, recur: false)
        
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
        
        let bucket = Bucket(name: "Savings", targetAmount: 500, income: 500 / secondsPerMonth / 3, whenFinished: .waitToDump, recur: false)
        
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
        
        let bucket = Bucket(name: "Savings", targetAmount: 300, income: 300 / secondsPerMonth * (2/3), whenFinished: .waitToDump, recur: true)
        
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
        
        XCTAssertEqual(result2.mainBalance, 8727.27, accuracy: 0.01) // - 500 (new bucket) + 272.73 (dumped)
        XCTAssertEqual(result2.buckets.count, 1)
        XCTAssertEqual(result2.buckets[0].amount, 272.73, accuracy: 0.01) // New bucket filling up again
    }

    func testRecurringBucketRefillsEvenWithoutEvent() {
        let oneMonthLater = Calendar.current.date(byAdding: .second, value: Int(secondsPerMonth), to: appData.startDate)!
        let oneMonthLaterMinusOneSecond = Calendar.current.date(byAdding: .second, value: Int(secondsPerMonth - 1), to: appData.startDate)!
        
        let bucket = Bucket(name: "Savings", targetAmount: 300, income: 300 / secondsPerMonth, whenFinished: .autoDump, recur: true)
        
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
            let result = appData.calculateTotalIncome(asOf: oneMonthLater)
            XCTAssertEqual(result.buckets.count, 1)
            XCTAssertEqual(result.mainBalance + result.buckets[0].amount, 3000, accuracy: 0.01)
            
            // The bucket hasn't recurred yet so it hasn't gotten added to the main balance
            XCTAssertEqual(result.mainBalance, 3000, accuracy: 0.01)
            XCTAssertEqual(result.buckets[0].amount, 0, accuracy: 0.01)
        }
    }
}
