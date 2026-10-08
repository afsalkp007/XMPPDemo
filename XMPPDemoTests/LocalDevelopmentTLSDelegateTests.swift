import XCTest
@testable import XMPPDemo

final class LocalDevelopmentTLSDelegateTests: XCTestCase {
    func testAllowsCertificateExceptionForLocalhost() {
        let url = URL(string: "https://localhost:5443/upload/image.jpg")!

        XCTAssertEqual(LocalDevelopmentTLSDelegate.certificateExceptionHosts(for: url), ["localhost"])
    }

    func testDoesNotAllowCertificateExceptionForPublicHost() {
        let url = URL(string: "https://example.com/upload/image.jpg")!

        XCTAssertTrue(LocalDevelopmentTLSDelegate.certificateExceptionHosts(for: url).isEmpty)
    }
}
