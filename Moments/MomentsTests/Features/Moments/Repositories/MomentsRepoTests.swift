//
//  MomentsRepoTests.swift
//  MomentsTests
//
//  Created by Jake Lin on 16/11/20.
//

import Foundation

import Quick
import Nimble
import RxSwift
import RxTest

@testable import Moments

private class MockUserDefaultsPersistentDataStore: PersistentDataStoreType {
    private(set) var momentsDetails: ReplaySubject<MomentsDetails> = .create(bufferSize: 1)

    private(set) var savedMomentsDetails: MomentsDetails?

    func save(momentsDetails: MomentsDetails) {
        savedMomentsDetails = momentsDetails
    }
}

private class MockGetMomentsByUserIDSession: GetMomentsByUserIDSessionType {
    private(set) var getMomentsHasbeenCalled = false
    private(set) var passedUserID: String = ""

    func getMoments(userID: String) -> Observable<MomentsDetails> {
        passedUserID = userID
        getMomentsHasbeenCalled = true

        return Observable.just(TestFixture.momentsDetails)
    }
}

private class MockUpdateMomentLikeSession: UpdateMomentLikeSessionType {
    private(set) var updateLikeHasbeenCalled = false
    private(set) var passedIsLiked: Bool = false
    private(set) var passedMomentID: String = ""
    private(set) var passedUserID: String = ""

    func updateLike(_ isLiked: Bool, momentID: String, fromUserID userID: String) -> Observable<MomentsDetails> {
        updateLikeHasbeenCalled = true
        passedIsLiked = isLiked
        passedMomentID = momentID
        passedUserID = userID

        return Observable.just(TestFixture.momentsDetails)
    }
}

final class MomentsRepoTests: QuickSpec {
    override func spec() {
        describe("MomentsRepo") {
            var testSubject: MomentsRepo!
            var mockUserDefaultsPersistentDataStore: MockUserDefaultsPersistentDataStore!
            var mockGetMomentsByUserIDSession: MockGetMomentsByUserIDSession!
            var mockUpdateMomentLikeSession: MockUpdateMomentLikeSession!
            var disposeBag: DisposeBag!

            beforeEach {
                mockUserDefaultsPersistentDataStore = MockUserDefaultsPersistentDataStore()
                mockGetMomentsByUserIDSession = MockGetMomentsByUserIDSession()
                mockUpdateMomentLikeSession = MockUpdateMomentLikeSession()
                disposeBag = DisposeBag()

                testSubject = MomentsRepo(persistentDataStore: mockUserDefaultsPersistentDataStore, getMomentsByUserIDSession: mockGetMomentsByUserIDSession, updateMomentLikeSession: mockUpdateMomentLikeSession)
            }

            context("getMoments(userID:)") {
                beforeEach {
                    testSubject.getMoments(userID: "1").subscribe().disposed(by: disposeBag)
                }

                it("should call `GetMomentsByUserIDSessionType.getMoments`") {
                    expect(mockGetMomentsByUserIDSession.getMomentsHasbeenCalled).to(beTrue())
                    expect(mockGetMomentsByUserIDSession.passedUserID).to(be("1"))
                }

                it("should save a `MomentsDetails` object") {
                    expect(mockUserDefaultsPersistentDataStore.savedMomentsDetails).to(equal(TestFixture.momentsDetails))
                }
            }

            context("updateLike(isLiked:momentID:fromUserID:)") {
                beforeEach {
                    testSubject.updateLike(isLiked: true, momentID: "0", fromUserID: "1").subscribe().disposed(by: disposeBag)
                }

                it("should call `UpdateMomentLikeSessionType.updateLike`") {
                    expect(mockUpdateMomentLikeSession.updateLikeHasbeenCalled).to(beTrue())
                    expect(mockUpdateMomentLikeSession.passedIsLiked).to(beTrue())
                    expect(mockUpdateMomentLikeSession.passedMomentID).to(be("0"))
                    expect(mockUpdateMomentLikeSession.passedUserID).to(be("1"))
                }

                it("should save a `MomentsDetails` object") {
                    expect(mockUserDefaultsPersistentDataStore.savedMomentsDetails).to(equal(TestFixture.momentsDetails))
                }
            }

            context("momentsDetails") {
                var testObserver: TestObserver<MomentsDetails>!

                beforeEach {
                    testObserver = TestObserver<MomentsDetails>()
                    testSubject.momentsDetails.subscribe(testObserver).disposed(by: disposeBag)
                }

                it("should be `nil` by default") {
                    expect(testObserver.lastElement).to(beNil())
                }

                context("when persistentDataStore has new data") {
                    beforeEach {
                        mockUserDefaultsPersistentDataStore.momentsDetails.onNext(TestFixture.momentsDetails)
                    }

                    it("should notify a next event with the new data") {
                        expect(testObserver.lastElement).toEventually(equal(TestFixture.momentsDetails))
                    }
                }
            }
        }
    }
}
