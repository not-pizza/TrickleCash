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
        
        let bucket = Bucket(dateAdded: appData.startDate, name: "Savings", targetAmount: 1000, contributionMode: .share(share: 1), whenFinished: .waitToDump, recur: false)
        
        appData.events = [
            .createBucket(bucket)
        ]
        
        let result = appData.calculateTotalIncome(asOf: oneMonthLater)
        
        XCTAssertEqual(result.mainBalance, 3000 * 10.0 / 11.0, accuracy: 0.01) // 10/11 of 3000
        XCTAssertEqual(result.buckets.count, 1)
        XCTAssertEqual(result.buckets[0].amount, 3000 - 3000 * 10.0 / 11.0, accuracy: 0.01) // 1/11 of 3000
    }
    
    func testBucketFilling() {
        let threeMonthsLater = Calendar.current.date(byAdding: .second, value: Int(secondsPerMonth * 3), to: appData.startDate)!
        
        let bucket = Bucket(dateAdded: appData.startDate, name: "Savings", targetAmount: 500, contributionMode: .share(share: 1), whenFinished: .waitToDump, recur: false)
        
        appData.events = [
            .createBucket(bucket)
        ]
        let result = appData.calculateTotalIncome(asOf: threeMonthsLater)
        XCTAssertEqual(result.mainBalance, 8500, accuracy: 0.01) // 9000 - 500
        XCTAssertEqual(result.buckets.count, 1)
        XCTAssertEqual(result.buckets[0].amount, 500, accuracy: 0.01) // Bucket should be full
        
        
        appData.events = [
            .createBucket(bucket),
            .dumpBucket(DumpBucket(dateAdded: threeMonthsLater, bucketToDump: bucket.id))
        ]
        let result2 = appData.calculateTotalIncome(asOf: threeMonthsLater)
        XCTAssertEqual(result2.mainBalance, 9000, accuracy: 0.01) // 9000 - 500 + 500
        XCTAssertEqual(result2.buckets.count, 0)
    }
    
    func testBucketDumpMidFill() {
        let oneMonthLater = Calendar.current.date(byAdding: .second, value: Int(secondsPerMonth), to: appData.startDate)!
        let twoMonthsLater = Calendar.current.date(byAdding: .second, value: Int(secondsPerMonth * 2), to: appData.startDate)!
        let threeMonthsLater = Calendar.current.date(byAdding: .second, value: Int(secondsPerMonth * 3), to: appData.startDate)!
        
        let bucket = Bucket(dateAdded: oneMonthLater, name: "Savings", targetAmount: 500, contributionMode: .share(share: 1), whenFinished: .waitToDump, recur: true)
        
        appData.events = [
            .createBucket(bucket),
        ]
        
        let result1 = appData.calculateTotalIncome(asOf: twoMonthsLater)
        XCTAssertEqual(result1.buckets.count, 1)
        XCTAssertEqual(result1.mainBalance + result1.buckets[0].amount, 6000, accuracy: 0.01) // We should have made 6000 over 2 months
        XCTAssertEqual(result1.buckets[0].amount, 272.72, accuracy: 0.01)
        
        appData.events = [
            .createBucket(bucket),
            .dumpBucket(DumpBucket(dateAdded: twoMonthsLater, bucketToDump: bucket.id))
        ]

        let result2 = appData.calculateTotalIncome(asOf: threeMonthsLater)
        
        XCTAssertEqual(result2.mainBalance, 8727.27, accuracy: 0.01) // - 500 (new bucket) + 272.73 (dumped)
        XCTAssertEqual(result2.buckets.count, 1)
        XCTAssertEqual(result2.buckets[0].amount, 272.73, accuracy: 0.01) // New bucket filling up again
    }
    
    func testByDurationBucket() {
        let oneMonthLater = Calendar.current.date(byAdding: .second, value: Int(secondsPerMonth), to: appData.startDate)!

        let bucket = Bucket(dateAdded: appData.startDate, name: "Weekly Savings", targetAmount: 1000, contributionMode: .byDuration(interval: 7 * 24 * 60 * 60), whenFinished: .waitToDump, recur: false)
        
        appData.events = [
            .createBucket(bucket)
        ]
        
        let result = appData.calculateTotalIncome(asOf: oneMonthLater)
        
        XCTAssertEqual(result.mainBalance, 2000, accuracy: 0.01)
        XCTAssertEqual(result.buckets.count, 1)
        XCTAssertEqual(result.buckets[0].amount, 1000, accuracy: 0.01) // Bucket should be full
    }
    
    func testMultipleByDurationBuckets() {
        let oneWeekLater = Calendar.current.date(byAdding: .second, value: Int(secondsPerWeek), to: appData.startDate)!
        let twoWeeksLater = Calendar.current.date(byAdding: .second, value: Int(2 * secondsPerWeek), to: appData.startDate)!
        let oneMonthLater = Calendar.current.date(byAdding: .second, value: Int(secondsPerMonth), to: appData.startDate)!

        let weeklyBucket = Bucket(dateAdded: appData.startDate, name: "Weekly Savings", targetAmount: 1000, contributionMode: .byDuration(interval: 7 * 24 * 60 * 60), whenFinished: .waitToDump, recur: false)
        let biweeklyBucket = Bucket(dateAdded: appData.startDate, name: "Biweekly Savings", targetAmount: 1000, contributionMode: .byDuration(interval: 14 * 24 * 60 * 60), whenFinished: .waitToDump, recur: false)
        
        appData.events = [
            .createBucket(weeklyBucket),
            .createBucket(biweeklyBucket)
        ]
        
        
        do {
            let resultOneWeek = appData.calculateTotalIncome(asOf: oneWeekLater)
            
            XCTAssertEqual(resultOneWeek.mainBalance, 0, accuracy: 0.01)
        }
        
        do {
            let resultTwoWeeks = appData.calculateTotalIncome(asOf: twoWeeksLater)
            
            XCTAssertEqual(resultTwoWeeks.mainBalance, 0, accuracy: 0.01)
        }
        
        do {
            let resultOneMonth = appData.calculateTotalIncome(asOf: oneMonthLater)
            let weeklyBucketResult = resultOneMonth.buckets.first { $0.bucket.name == "Weekly Savings" }!
            let biweeklyBucketResult = resultOneMonth.buckets.first { $0.bucket.name == "Biweekly Savings" }!

            XCTAssertEqual(resultOneMonth.mainBalance, 1000, accuracy: 0.01)
            XCTAssertEqual(resultOneMonth.buckets.count, 2)
            
            XCTAssertNotNil(weeklyBucketResult)
            XCTAssertEqual(weeklyBucketResult.amount, 1000, accuracy: 0.01) // Should be full
            
            XCTAssertNotNil(biweeklyBucketResult)
            XCTAssertEqual(biweeklyBucketResult.amount, 1000, accuracy: 0.01) // Should be full
        }
    }
    
    func testByDurationBucketScaling() {
        let oneMonthLater = Calendar.current.date(byAdding: .second, value: Int(secondsPerMonth), to: appData.startDate)!

        let s1 = Bucket(dateAdded: appData.startDate, name: "S1", targetAmount: 5000, contributionMode: .byDuration(interval: secondsPerMonth / 4), whenFinished: .waitToDump, recur: false)
        let s2 = Bucket(dateAdded: appData.startDate, name: "S2", targetAmount: 5000, contributionMode: .byDuration(interval: secondsPerMonth / 2), whenFinished: .waitToDump, recur: false)
        
        appData.events = [
            .createBucket(s1),
            .createBucket(s2)
        ]
        
        let result = appData.calculateTotalIncome(asOf: oneMonthLater)
        
        XCTAssertEqual(result.mainBalance, 0, accuracy: 0.01) // All income should go to buckets
        XCTAssertEqual(result.buckets.count, 2)
        
        let s1Result = result.buckets.first { $0.bucket.name == "S1" }!
        XCTAssertNotNil(s1Result)
        XCTAssertEqual(s1Result.amount, 2000, accuracy: 0.01) // 2/3 of monthly income
        
        let s2Result = result.buckets.first { $0.bucket.name == "S2" }!
        XCTAssertNotNil(s2Result)
        XCTAssertEqual(s2Result.amount, 1000, accuracy: 0.01) // 1/3 of monthly income
    }
    
    func testByDurationAndShareBuckets() {
        let oneMonthLater = Calendar.current.date(byAdding: .second, value: Int(secondsPerMonth), to: appData.startDate)!

        let weeklyBucket = Bucket(dateAdded: appData.startDate, name: "Weekly Savings", targetAmount: 2000, contributionMode: .byDuration(interval: secondsPerWeek), whenFinished: .waitToDump, recur: false)
        let shareBucket = Bucket(dateAdded: appData.startDate, name: "Share Savings", targetAmount: 2000, contributionMode: .share(share: 1), whenFinished: .waitToDump, recur: false)
        
        appData.events = [
            .createBucket(weeklyBucket),
            .createBucket(shareBucket)
        ]
        
        let result = appData.calculateTotalIncome(asOf: oneMonthLater)
        
        XCTAssertEqual(result.buckets.count, 2)
        
        let weeklyBucketResult = result.buckets.first { $0.bucket.name == "Weekly Savings" }
        XCTAssertNotNil(weeklyBucketResult)
        XCTAssertEqual(weeklyBucketResult!.amount, 2000, accuracy: 0.01) // Should be full
        
        let shareBucketResult = result.buckets.first { $0.bucket.name == "Share Savings" }
        XCTAssertNotNil(shareBucketResult)
        XCTAssertEqual(shareBucketResult!.amount, 90.91, accuracy: 0.01) // (3000 - 2000) / 11
        
        XCTAssertEqual(result.mainBalance, 909.09, accuracy: 0.01) // 10 * (3000 - 2000) / 11
    }

}


class DistributeAccordingToSharesTests: XCTestCase {
    
    func testEqualSharesNoCaps() {
        let amount = 100.0
        let distributees = [(cap: nil as Double?, share: 1.0), (cap: nil, share: 1.0), (cap: nil, share: 1.0)]
        let result = Bucket.distributeAccordingToShares(amount: amount, distributees: distributees)
        
        XCTAssertEqual(result.remainder, 0.0, accuracy: 0.001)
        XCTAssertEqual(result.distributions.count, 3)
        for distribution in result.distributions {
            XCTAssertEqual(distribution, 33.333, accuracy: 0.001)
        }
    }
    
    func testUnequalSharesNoCaps() {
        let amount = 100.0
        let distributees = [(cap: nil as Double?, share: 1.0), (cap: nil, share: 2.0), (cap: nil, share: 3.0)]
        let result = Bucket.distributeAccordingToShares(amount: amount, distributees: distributees)
        
        XCTAssertEqual(result.remainder, 0.0, accuracy: 0.001)
        XCTAssertEqual(result.distributions.count, 3)
        XCTAssertEqual(result.distributions[0], 16.667, accuracy: 0.001)
        XCTAssertEqual(result.distributions[1], 33.333, accuracy: 0.001)
        XCTAssertEqual(result.distributions[2], 50.0, accuracy: 0.001)
    }
    
    func testWithCaps() {
        let amount = 100.0
        let distributees = [(cap: 20.0 as Double?, share: 1.0), (cap: 30.0, share: 1.0), (cap: nil, share: 1.0)]
        let result = Bucket.distributeAccordingToShares(amount: amount, distributees: distributees)
        
        XCTAssertEqual(result.remainder, 0.0, accuracy: 0.001)
        XCTAssertEqual(result.distributions.count, 3)
        XCTAssertEqual(result.distributions[0], 20.0, accuracy: 0.001)
        XCTAssertEqual(result.distributions[1], 30.0, accuracy: 0.001)
        XCTAssertEqual(result.distributions[2], 50.0, accuracy: 0.001)
    }
    
    func testExceedingAmount() {
        let amount = 50.0
        let distributees = [(cap: 20.0 as Double?, share: 1.0), (cap: 30.0, share: 1.0), (cap: nil, share: 1.0)]
        let result = Bucket.distributeAccordingToShares(amount: amount, distributees: distributees)
        
        XCTAssertEqual(result.remainder, 0.0, accuracy: 0.001)
        XCTAssertEqual(result.distributions.count, 3)
        for distribution in result.distributions {
            XCTAssertEqual(distribution, 16.667, accuracy: 0.001)
        }
    }
    
    
    func testInsufficientAmount() {
        let amount = 10.0
        let distributees = [(cap: 20.0 as Double?, share: 1.0), (cap: 30.0, share: 2.0), (cap: nil, share: 3.0)]
        let result = Bucket.distributeAccordingToShares(amount: amount, distributees: distributees)
        
        XCTAssertEqual(result.remainder, 0.0, accuracy: 0.001)
        XCTAssertEqual(result.distributions.count, 3)
        XCTAssertEqual(result.distributions[0], 1.667, accuracy: 0.001)
        XCTAssertEqual(result.distributions[1], 3.333, accuracy: 0.001)
        XCTAssertEqual(result.distributions[2], 5.0, accuracy: 0.001)
    }
    
    func testZeroAmount() {
        let amount = 0.0
        let distributees = [(cap: nil as Double?, share: 1.0), (cap: nil, share: 1.0)]
        let result = Bucket.distributeAccordingToShares(amount: amount, distributees: distributees)
        
        XCTAssertEqual(result.remainder, 0.0)
        XCTAssertEqual(result.distributions, [0.0, 0.0])
    }
    
    func testNoDistributees() {
        let amount = 100.0
        let distributees: [(cap: Double?, share: Double)] = []
        let result = Bucket.distributeAccordingToShares(amount: amount, distributees: distributees)
        
        XCTAssertEqual(result.remainder, 100.0)
        XCTAssertEqual(result.distributions, [])
    }
}
