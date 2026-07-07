import Testing
import Foundation
@testable import Life_XP_iOS

@Suite("Headphone Exposure Evaluation")
struct HeadphoneExposureEvaluationTests {

    @Test func evaluate_passesWhenAverageUnderThreshold() {
        #expect(evaluateHeadphoneHabit(average: 70.0, maxDecibels: 85.0) == true)
    }

    @Test func evaluate_passesWhenAverageExactlyAtThreshold() {
        #expect(evaluateHeadphoneHabit(average: 85.0, maxDecibels: 85.0) == true)
    }

    @Test func evaluate_failsWhenAverageOverThreshold() {
        #expect(evaluateHeadphoneHabit(average: 90.0, maxDecibels: 85.0) == false)
    }

    @Test func evaluate_passesWhenNoSamples() {
        #expect(evaluateHeadphoneHabit(average: nil, maxDecibels: 85.0) == true)
    }
}
