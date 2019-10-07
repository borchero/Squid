import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(SquidRequestTests.allTests),
        testCase(SquidUtilityTests.allTests)
    ]
}
#endif
