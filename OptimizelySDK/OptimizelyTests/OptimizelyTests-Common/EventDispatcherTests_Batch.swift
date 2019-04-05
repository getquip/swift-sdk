//
//  EventDispatcherTests_Batch.swift
//  OptimizelySwiftSDK
//
//  Created by Jae Kim on 3/13/19.
//  Copyright © 2019 Optimizely. All rights reserved.
//

import XCTest
import SwiftyJSON

class EventDispatcherTests_Batch: XCTestCase {
    
    let kRevision = "321"
    let kAccountId = "11111"
    let kProjectId = "33333"
    let kClientVersion = "3.1.2"
    let kClientName = "swift-sdk"
    let kAnonymizeIP = true
    let kEnrichDecision = true
    
    let kUrlA = "https://urla.com"
    let kUrlB = "https://urlb.com"
    let kUrlC = "https://urlb.com"

    let kUserIdA = "123"
    let kUserIdB = "456"
    let kUserIdC = "789"
    
    var eventDispatcher: TestEventDispatcher!
    
    override func setUp() {
        self.eventDispatcher = TestEventDispatcher(resetPendingEvents: true)
    }
    
    override func tearDown() {
        // make sure timer off at the of each test to avoid interference
        
        self.eventDispatcher.timer.performAtomic { $0.invalidate() }
    }

}

// MARK: - Batch

extension EventDispatcherTests_Batch {

    func testBatchingEvents() {
        let events: [EventForDispatch] = [
            makeEventForDispatch(url: kUrlA, event: batchEventA),
            makeEventForDispatch(url: kUrlA, event: batchEventB),
            makeEventForDispatch(url: kUrlA, event: batchEventB),
            makeEventForDispatch(url: kUrlA, event: batchEventA)
        ]

        let batch = events.batch()!
        let batchedEvents = try! JSONDecoder().decode(BatchEvent.self, from: batch.body)
        XCTAssertEqual(batch.url.absoluteString, kUrlA)
        XCTAssertEqual(batchedEvents.revision, kRevision)
        XCTAssertEqual(batchedEvents.accountID, kAccountId)
        XCTAssertEqual(batchedEvents.projectID, kProjectId)
        XCTAssertEqual(batchedEvents.clientVersion, kClientVersion)
        XCTAssertEqual(batchedEvents.clientName, kClientName)
        XCTAssertEqual(batchedEvents.anonymizeIP, kAnonymizeIP)
        XCTAssertEqual(batchedEvents.enrichDecisions, kEnrichDecision)
        XCTAssertEqual(batchedEvents.visitors.count, events.count)
        XCTAssertEqual(batchedEvents.visitors[0], visitorA)
        XCTAssertEqual(batchedEvents.visitors[1], visitorB)
        XCTAssertEqual(batchedEvents.visitors[2], visitorB)
        XCTAssertEqual(batchedEvents.visitors[3], visitorA)
    }

    func testBatchingEventsWhenUrlsNotEqual() {
        let events: [EventForDispatch] = [
            makeEventForDispatch(url: kUrlA, event: batchEventA),
            makeEventForDispatch(url: kUrlB, event: batchEventB)
        ]

        let batch = events.batch()
        XCTAssertNil(batch)
    }

    func testBatchingEventsWhenProjectIdsNotEqual() {
        let be1 = batchEventA
        var be2 = batchEventA
        be2.projectID = "99999"

        let events: [EventForDispatch] = [
            makeEventForDispatch(url: kUrlA, event: be1),
            makeEventForDispatch(url: kUrlB, event: be2)
        ]

        let batch = events.batch()
        XCTAssertNil(batch)
    }
    
}

// MARK: - FlushEvents

extension EventDispatcherTests_Batch {

    func testFlushEvents() {
        eventDispatcher.dispatchEvent(event: makeEventForDispatch(url: kUrlA, event: batchEventA), completionHandler: nil)
        eventDispatcher.dispatchEvent(event: makeEventForDispatch(url: kUrlA, event: batchEventB), completionHandler: nil)
        eventDispatcher.dispatchEvent(event: makeEventForDispatch(url: kUrlA, event: batchEventA), completionHandler: nil)
        
        eventDispatcher.flushEvents()
        eventDispatcher.dispatcher.sync {}
        
        XCTAssertEqual(eventDispatcher.sendRequestedEvents.count, 1)
        let batch = eventDispatcher.sendRequestedEvents[0]
        let batchedEvents = try! JSONDecoder().decode(BatchEvent.self, from: batch.body)
        XCTAssertEqual(batch.url.absoluteString, kUrlA)
        XCTAssertEqual(batchedEvents.revision, kRevision)
        XCTAssertEqual(batchedEvents.accountID, kAccountId)
        XCTAssertEqual(batchedEvents.projectID, kProjectId)
        XCTAssertEqual(batchedEvents.clientVersion, kClientVersion)
        XCTAssertEqual(batchedEvents.clientName, kClientName)
        XCTAssertEqual(batchedEvents.anonymizeIP, kAnonymizeIP)
        XCTAssertEqual(batchedEvents.enrichDecisions, kEnrichDecision)
        XCTAssertEqual(batchedEvents.visitors[0], visitorA)
        XCTAssertEqual(batchedEvents.visitors[1], visitorB)
        XCTAssertEqual(batchedEvents.visitors[2], visitorA)
        XCTAssertEqual(batchedEvents.visitors.count, 3)
        XCTAssertEqual(eventDispatcher.dataStore.count, 0)
    }
    
    func testFlushEventsWhenBatchFails() {
        eventDispatcher.dispatchEvent(event: makeEventForDispatch(url: kUrlA, event: batchEventA), completionHandler: nil)
        eventDispatcher.dispatchEvent(event: makeEventForDispatch(url: kUrlA, event: batchEventA), completionHandler: nil)
        eventDispatcher.dispatchEvent(event: makeEventForDispatch(url: kUrlB, event: batchEventB), completionHandler: nil)
        
        eventDispatcher.flushEvents()
        eventDispatcher.dispatcher.sync {}
        
        XCTAssertEqual(eventDispatcher.sendRequestedEvents.count, 3, "no batch expected since urls are all different, so each sent separately")
        
        var batch = eventDispatcher.sendRequestedEvents[0]
        var batchedEvents = try! JSONDecoder().decode(BatchEvent.self, from: batch.body)
        XCTAssertEqual(batchedEvents.revision, kRevision)
        XCTAssertEqual(batchedEvents.accountID, kAccountId)
        XCTAssertEqual(batchedEvents.projectID, kProjectId)
        XCTAssertEqual(batchedEvents.clientVersion, kClientVersion)
        XCTAssertEqual(batchedEvents.clientName, kClientName)
        XCTAssertEqual(batchedEvents.anonymizeIP, kAnonymizeIP)
        XCTAssertEqual(batchedEvents.enrichDecisions, kEnrichDecision)
        XCTAssertEqual(batch.url.absoluteString, kUrlA)
        XCTAssertEqual(batchedEvents.visitors[0], visitorA)
        XCTAssertEqual(batchedEvents.visitors.count, 1)
        
        // Note that 1st 2 events (kUrlA, kUrlA) can be batched though the next 2 events are not
        // but we do not batch them if we cannot batch all, so it's expected they are all sent out individually
        
        batch = eventDispatcher.sendRequestedEvents[1]
        batchedEvents = try! JSONDecoder().decode(BatchEvent.self, from: batch.body)
        XCTAssertEqual(batchedEvents.revision, kRevision)
        XCTAssertEqual(batchedEvents.accountID, kAccountId)
        XCTAssertEqual(batchedEvents.projectID, kProjectId)
        XCTAssertEqual(batchedEvents.clientVersion, kClientVersion)
        XCTAssertEqual(batchedEvents.clientName, kClientName)
        XCTAssertEqual(batchedEvents.anonymizeIP, kAnonymizeIP)
        XCTAssertEqual(batchedEvents.enrichDecisions, kEnrichDecision)
        XCTAssertEqual(batch.url.absoluteString, kUrlA)
        XCTAssertEqual(batchedEvents.visitors[0], visitorA)
        XCTAssertEqual(batchedEvents.visitors.count, 1)
        
        batch = eventDispatcher.sendRequestedEvents[2]
        batchedEvents = try! JSONDecoder().decode(BatchEvent.self, from: batch.body)
        XCTAssertEqual(batchedEvents.revision, kRevision)
        XCTAssertEqual(batchedEvents.accountID, kAccountId)
        XCTAssertEqual(batchedEvents.projectID, kProjectId)
        XCTAssertEqual(batchedEvents.clientVersion, kClientVersion)
        XCTAssertEqual(batchedEvents.clientName, kClientName)
        XCTAssertEqual(batchedEvents.anonymizeIP, kAnonymizeIP)
        XCTAssertEqual(batchedEvents.enrichDecisions, kEnrichDecision)
        XCTAssertEqual(batch.url.absoluteString, kUrlB)
        XCTAssertEqual(batchedEvents.visitors[0], visitorB)
        XCTAssertEqual(batchedEvents.visitors.count, 1)
        
        XCTAssertEqual(eventDispatcher.dataStore.count, 0)
    }
    
    func testFlushEventsWhenSendEventFails() {
        eventDispatcher.forceError = true

        eventDispatcher.dispatchEvent(event: makeEventForDispatch(url: kUrlA, event: batchEventA), completionHandler: nil)
        eventDispatcher.dispatchEvent(event: makeEventForDispatch(url: kUrlA, event: batchEventA), completionHandler: nil)
        
        eventDispatcher.flushEvents()
        eventDispatcher.dispatcher.sync {}
        
        let maxFailureCount = 3 + 1   // DefaultEventDispatcher.MAX_FAILURE_COUNT + 1
        
        XCTAssertEqual(eventDispatcher.sendRequestedEvents.count, maxFailureCount, "repeated the same request several times before giveup")
        
        let batch = eventDispatcher.sendRequestedEvents[0]
        let batchedEvents = try! JSONDecoder().decode(BatchEvent.self, from: batch.body)
        XCTAssertEqual(batch.url.absoluteString, kUrlA)
        XCTAssertEqual(batchedEvents.visitors[0], visitorA)
        XCTAssertEqual(batchedEvents.visitors[1], visitorA)
        XCTAssertEqual(batchedEvents.visitors.count, 2)
        
        XCTAssertEqual(eventDispatcher.sendRequestedEvents[1], eventDispatcher.sendRequestedEvents[0])
        XCTAssertEqual(eventDispatcher.sendRequestedEvents[2], eventDispatcher.sendRequestedEvents[0])
        XCTAssertEqual(eventDispatcher.sendRequestedEvents[3], eventDispatcher.sendRequestedEvents[0])

        XCTAssertEqual(eventDispatcher.dataStore.count, 2, "all failed to transmit, so should keep all original events")
    }

    func testFlushEventsWhenSendEventFailsAndRecovers() {
        // (1) error injected - all event send fails
        
        eventDispatcher.forceError = true
        
        eventDispatcher.dispatchEvent(event: makeEventForDispatch(url: kUrlA, event: batchEventA), completionHandler: nil)
        eventDispatcher.dispatchEvent(event: makeEventForDispatch(url: kUrlA, event: batchEventA), completionHandler: nil)
        
        eventDispatcher.flushEvents()
        eventDispatcher.dispatcher.sync {}
        
        let maxFailureCount = 3 + 1   // DefaultEventDispatcher.MAX_FAILURE_COUNT + 1
        
        XCTAssertEqual(eventDispatcher.sendRequestedEvents.count, maxFailureCount, "repeated the same request several times before giveup")
        
        let batch = eventDispatcher.sendRequestedEvents[0]
        let batchedEvents = try! JSONDecoder().decode(BatchEvent.self, from: batch.body)
        XCTAssertEqual(batch.url.absoluteString, kUrlA)
        XCTAssertEqual(batchedEvents.visitors[0], visitorA)
        XCTAssertEqual(batchedEvents.visitors[1], visitorA)
        XCTAssertEqual(batchedEvents.visitors.count, 2)
        
        XCTAssertEqual(eventDispatcher.sendRequestedEvents[1], eventDispatcher.sendRequestedEvents[0])
        XCTAssertEqual(eventDispatcher.sendRequestedEvents[2], eventDispatcher.sendRequestedEvents[0])
        XCTAssertEqual(eventDispatcher.sendRequestedEvents[3], eventDispatcher.sendRequestedEvents[0])
        
        XCTAssertEqual(eventDispatcher.dataStore.count, 2, "all failed to transmit, so should keep all original events")
        
        // (2) error removed - now events sent out successfully
        
        eventDispatcher.forceError = false
        
        // assume flushEvents called again on next timer fire
        eventDispatcher.flushEvents()
        eventDispatcher.dispatcher.sync {}

        XCTAssertEqual(eventDispatcher.sendRequestedEvents.count, maxFailureCount + 1, "only one more since succeeded")
        XCTAssertEqual(eventDispatcher.sendRequestedEvents[3], eventDispatcher.sendRequestedEvents[0])
        
        XCTAssertEqual(eventDispatcher.dataStore.count, 0, "all expected to get transmitted successfully")
    }

}

// MARK: - Timer-fired FlushEvents

extension EventDispatcherTests_Batch {

    func testEventDispatchedOnTimer() {
        eventDispatcher.timerInterval = 3

        eventDispatcher.exp = expectation(description: "timer")

        eventDispatcher.dispatchEvent(event: makeEventForDispatch(url: kUrlA, event: batchEventA), completionHandler: nil)

        wait(for: [eventDispatcher.exp!], timeout: 10)

        let batch = eventDispatcher.sendRequestedEvents[0]
        let batchedEvents = try! JSONDecoder().decode(BatchEvent.self, from: batch.body)
        XCTAssertEqual(batch.url.absoluteString, kUrlA)
        XCTAssertEqual(batchedEvents.visitors[0], visitorA)
        XCTAssertEqual(batchedEvents.visitors.count, 1)
    }
    
    func testEventBatchedOnTimer() {
        eventDispatcher.timerInterval = 3

        eventDispatcher.exp = expectation(description: "timer")

        eventDispatcher.dispatchEvent(event: makeEventForDispatch(url: kUrlA, event: batchEventA), completionHandler: nil)
        sleep(1)
        eventDispatcher.dispatchEvent(event: makeEventForDispatch(url: kUrlA, event: batchEventB), completionHandler: nil)

        wait(for: [eventDispatcher.exp!], timeout: 10)
        XCTAssert(eventDispatcher.sendRequestedEvents.count > 0)

        let batch = eventDispatcher.sendRequestedEvents[0]
        let batchedEvents = try! JSONDecoder().decode(BatchEvent.self, from: batch.body)
        XCTAssertEqual(batch.url.absoluteString, kUrlA)
        XCTAssertEqual(batchedEvents.visitors[0], visitorA)
        XCTAssertEqual(batchedEvents.visitors[1], visitorB)
        XCTAssertEqual(batchedEvents.visitors.count, 2)
        
        XCTAssertEqual(eventDispatcher.dataStore.count, 0, "all expected to get transmitted successfully")
    }
    
    func testEventBatchedOnTimer_CheckNoRedundantSend() {
        eventDispatcher.timerInterval = 3

        eventDispatcher.exp = expectation(description: "timer")

        eventDispatcher.dispatchEvent(event: makeEventForDispatch(url: kUrlA, event: batchEventA), completionHandler: nil)
        eventDispatcher.dispatchEvent(event: makeEventForDispatch(url: kUrlA, event: batchEventB), completionHandler: nil)

        // wait for the 1st batched event transmitted successfully
        wait(for: [eventDispatcher.exp!], timeout: 10)

        // wait more for multiple timer fires to make sure there is no redandant sent out
        sleep(10)

        // check if we have only one batched event transmitted
        XCTAssert(eventDispatcher.sendRequestedEvents.count == 1)

        XCTAssertEqual(eventDispatcher.dataStore.count, 0, "all expected to get transmitted successfully")
    }

    func testEventBatchedAndErrorRecoveredOnTimer() {
        eventDispatcher.timerInterval = 5

        // (1) inject error

        eventDispatcher.forceError = true
        eventDispatcher.exp = expectation(description: "timer")

        eventDispatcher.dispatchEvent(event: makeEventForDispatch(url: kUrlA, event: batchEventA), completionHandler: nil)
        sleep(1)
        eventDispatcher.dispatchEvent(event: makeEventForDispatch(url: kUrlA, event: batchEventB), completionHandler: nil)

        // wait for the first timer-fire
        wait(for: [eventDispatcher.exp!], timeout: 10)
        // tranmission is expected to fail
        XCTAssertEqual(eventDispatcher.dataStore.count, 2, "all failed to transmit, so should keep all original events")

        // (2) remove error. check if events are transmitted successfully on next timer-fire
        sleep(3)   // wait all failure-retries (3 times) completed
        eventDispatcher.forceError = false
        eventDispatcher.exp = expectation(description: "timer")

        // wait for the next timer-fire
        wait(for: [eventDispatcher.exp!], timeout: 10)

        XCTAssertEqual(eventDispatcher.dataStore.count, 0, "all expected to get transmitted successfully")
    }

}

// MARK: - Utils

extension EventDispatcherTests_Batch {
    
    func makeEventForDispatch(url: String, event: BatchEvent) -> EventForDispatch {
        let data = try! JSONEncoder().encode(event)
        return EventForDispatch(url: URL(string: url), body: data)
    }
    
    var emptyBatchEvent: BatchEvent {
        return BatchEvent(revision: kRevision,
                          accountID: kAccountId,
                          clientVersion: kClientVersion,
                          visitors: [],
                          projectID: kProjectId,
                          clientName: kClientName,
                          anonymizeIP: kAnonymizeIP,
                          enrichDecisions: kEnrichDecision)
    }
    
    var batchEventA: BatchEvent {
        var event = emptyBatchEvent
        event.visitors = [visitorA]
        return event
    }
    
    var batchEventB: BatchEvent {
        var event = emptyBatchEvent
        event.visitors = [visitorB]
        return event
    }

    var batchEventC: BatchEvent {
        var event = emptyBatchEvent
        event.visitors = [visitorC]
        return event
    }

    var visitorA: Visitor {
        return Visitor(attributes: [],
                       snapshots: [],
                       visitorID: kUserIdA)
    }
    
    var visitorB: Visitor {
        return Visitor(attributes: [],
                       snapshots: [],
                       visitorID: kUserIdB)
    }

    var visitorC: Visitor {
        return Visitor(attributes: [],
                       snapshots: [],
                       visitorID: kUserIdC)
    }

}

// MARK: - Fake EventDispatcher

class TestEventDispatcher: DefaultEventDispatcher {
    var sendRequestedEvents: [EventForDispatch] = []
    var forceError = false
    
    // set this if need to wait sendEvent completed
    var exp: XCTestExpectation?
    
    init(resetPendingEvents: Bool) {
        super.init()
        
        if resetPendingEvents {
            _ = dataStore.removeLastItems(count: 1000)
        }
    }
    
    override func sendEvent(event: EventForDispatch, completionHandler: @escaping DispatchCompletionHandler) {
        sendRequestedEvents.append(event)

        // must call completionHandler to complete synchronization
        super.sendEvent(event: event) { result in
            if self.forceError {
                completionHandler(.failure(OPTEventDispatchError(description: "error")))
            } else {
                // return success to clear store after sending events
                completionHandler(.success(Data()))
            }

            self.exp?.fulfill()
            self.exp = nil   // nullify to avoid repeated calls
        }
    }
    
}

