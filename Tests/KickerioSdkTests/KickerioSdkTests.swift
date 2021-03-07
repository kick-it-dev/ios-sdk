import XCTest
import Alamofire
@testable import KickerioSdk

final class KickerioSdkTests: XCTestCase {
    func testAppTargetHit() {
        // Using version equals to 1.0.1 which is a target for the given key

        let apiKey = "6d71d7ebb9e2c0ed.dd24791ce6985c526497ec3fdcb4126521deff88f613db6680eea15a0d9f9b00"
        let params = [
            "someKey": "someValue",
            "moreArgs": "moreValues"
        ]
        // User-Agent: AppName/Version(BuildNumber) Platform/PlatformVersion
        let userAgentString = "KickerApp/1.0.1(20901) iOS/10.3"
        let kickerioSdk = KickerioSdk()
        var kickerResponse: KickerioResponse?
        let exp = self.expectation(description: "KickerioSdk Call")

        kickerioSdk.checkApplicationDeprecation(apiKey: apiKey, userAgentString: userAgentString, parameters: params) { result in

            kickerResponse = result.value
            
            XCTAssertEqual(kickerResponse?.matched, true)
            XCTAssertEqual(kickerResponse?.message, "Please update the app to the newest version on the App Store")
            
            XCTAssertNotNil(kickerResponse?.targetMeta)
            XCTAssertEqual(kickerResponse?.targetMeta?.appName, "KickerApp")
            XCTAssertEqual(kickerResponse?.targetMeta?.buildNumber, "20901")
            XCTAssertEqual(kickerResponse?.targetMeta?.platform, "ios")
            XCTAssertEqual(kickerResponse?.targetMeta?.version, "1.0.1")
            XCTAssertEqual(kickerResponse?.targetMeta?.hardDeprecation, true)

            exp.fulfill()
        }

        waitForExpectations(timeout: 3, handler: nil)
    }

    func testAppTargetNotHit() {
        // Using version equals to 1.0.0 which is not a target for the given key

        let apiKey = "6d71d7ebb9e2c0ed.dd24791ce6985c526497ec3fdcb4126521deff88f613db6680eea15a0d9f9b00"
        let params = [
            "someKey": "someValue",
            "moreArgs": "moreValues"
        ]
        // User-Agent: AppName/Version(BuildNumber) Platform/PlatformVersion
        let userAgentString = "KickerApp/1.0.0(20901) iOS/10.3"
        let exp = expectation(description: "Alamofire")

        KickerioSdk().checkApplicationDeprecation(apiKey: apiKey, userAgentString: userAgentString, parameters: params) { result in
            let kickerResponse: KickerioResponse? = result.value

            XCTAssertEqual(kickerResponse?.matched, false)
            XCTAssertEqual(kickerResponse?.message, "No app version matched")
            XCTAssertNil(kickerResponse?.targetMeta)
            
            exp.fulfill()
        }

        waitForExpectations(timeout: 3, handler: nil)
    }

    static var allTests = [
        ("testAppTargetHit", testAppTargetHit),
        ("testAppTargetNotHit", testAppTargetNotHit),
    ]
}
