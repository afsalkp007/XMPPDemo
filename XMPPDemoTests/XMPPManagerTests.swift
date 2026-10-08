import XCTest
@testable import XMPPDemo

@MainActor
final class XMPPManagerTests: XCTestCase {
    
    var manager: XMPPManager!
    
    override func setUp() {
        super.setUp()
        manager = XMPPManager()
    }
    
    override func tearDown() {
        manager = nil
        super.tearDown()
    }
    
    func testDisconnectClearsStreamManagementState() async {
        // 1. Simulate an active Stream Management session
        await manager.test_setSMState(
            id: "fake-sm-id-123",
            inH: 5,
            outH: 10,
            unacked: [(UInt32(10), "<message id='1'/>")]
        )
        
        let id = await manager.test_smID
        XCTAssertEqual(id, "fake-sm-id-123")
        
        let inH = await manager.test_smInH
        XCTAssertEqual(inH, 5)
        
        let outH = await manager.test_smOutH
        XCTAssertEqual(outH, 10)
        
        let count = await manager.test_unackedStanzasCount
        XCTAssertEqual(count, 1)
        
        // 2. Trigger disconnect (explicit logout)
        await manager.disconnect()
        
        // 3. Verify state is completely wiped
        let newId = await manager.test_smID
        XCTAssertNil(newId)
        
        let newInH = await manager.test_smInH
        XCTAssertEqual(newInH, 0)
        
        let newOutH = await manager.test_smOutH
        XCTAssertEqual(newOutH, 0)
        
        let newCount = await manager.test_unackedStanzasCount
        XCTAssertEqual(newCount, 0)
    }
}
