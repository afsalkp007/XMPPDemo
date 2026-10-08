import XCTest
@testable import XMPPDemo

@MainActor
final class AuthViewModelTests: XCTestCase {
    
    // MARK: - isFormValid Tests
    
    func testIsFormValidWithMissingJIDIsFalse() {
        let vm = AuthViewModel()
        vm.jid = ""
        vm.password = "password123"
        
        XCTAssertFalse(vm.isFormValid)
    }
    
    func testIsFormValidWithMissingPasswordIsFalse() {
        let vm = AuthViewModel()
        vm.jid = "alice@localhost"
        vm.password = ""
        
        XCTAssertFalse(vm.isFormValid)
    }
    
    func testIsFormValidWithMissingAtSymbolInJIDIsFalse() {
        let vm = AuthViewModel()
        vm.jid = "alicelocalhost"
        vm.password = "password123"
        
        XCTAssertFalse(vm.isFormValid)
    }
    
    func testIsFormValidWithWhitespaceJIDIsFalse() {
        let vm = AuthViewModel()
        vm.jid = "    "
        vm.password = "password123"
        
        XCTAssertFalse(vm.isFormValid)
    }
    
    func testIsFormValidWithValidCredentialsIsTrue() {
        let vm = AuthViewModel()
        vm.jid = "alice@localhost"
        vm.password = "password123"
        
        XCTAssertTrue(vm.isFormValid)
    }
    
    // MARK: - Field Errors Tests
    
    func testLoginValidationSetsFieldErrorsForEmptyJID() async {
        let vm = AuthViewModel()
        vm.jid = ""
        vm.password = "password123"
        
        await vm.login()
        
        XCTAssertEqual(vm.fieldErrors.jid, "JID is required")
        XCTAssertNil(vm.fieldErrors.password)
    }
    
    func testLoginValidationSetsFieldErrorsForInvalidJIDFormat() async {
        let vm = AuthViewModel()
        vm.jid = "alice"
        vm.password = "password123"
        
        await vm.login()
        
        XCTAssertEqual(vm.fieldErrors.jid, "Must be in user@domain format")
        XCTAssertNil(vm.fieldErrors.password)
    }
    
    func testLoginValidationSetsFieldErrorsForEmptyPassword() async {
        let vm = AuthViewModel()
        vm.jid = "alice@localhost"
        vm.password = ""
        
        await vm.login()
        
        XCTAssertNil(vm.fieldErrors.jid)
        XCTAssertEqual(vm.fieldErrors.password, "Password is required")
    }
}
