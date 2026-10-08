import XCTest
@testable import XMPPDemo

final class CryptoServiceTests: XCTestCase {
    
    func testGenerateAndRetrievePublicKey() throws {
        // Since tests might run on a simulator without Secure Enclave, our software fallback will trigger.
        let pubKey = try CryptoService.shared.getMyPublicKeyBase64()
        XCTAssertFalse(pubKey.isEmpty, "Public key should not be empty")
        
        // Calling it twice should retrieve the same cached key from Keychain
        let pubKey2 = try CryptoService.shared.getMyPublicKeyBase64()
        XCTAssertEqual(pubKey, pubKey2, "Public key should be persisted and stable")
    }
    
    func testEndToEndEncryptionCycle() throws {
        // 1. Get our own public key (we will act as both sender and recipient for this test)
        let myPubKey = try CryptoService.shared.getMyPublicKeyBase64()
        
        // 2. The plaintext payload
        let plaintext = "Top Secret XMPP Message"
        let payloadData = plaintext.data(using: .utf8)!
        
        // 3. Encrypt the payload using our own public key
        let (ciphertext, _) = try CryptoService.shared.encrypt(payload: payloadData, recipientPublicKeyBase64: myPubKey)
        
        XCTAssertNotEqual(ciphertext, plaintext, "Ciphertext should not be plaintext")
        
        // 4. Decrypt the payload using our own public key
        let decryptedData = try CryptoService.shared.decrypt(combinedBase64: ciphertext, senderPublicKeyBase64: myPubKey)
        let decryptedString = String(data: decryptedData, encoding: .utf8)
        
        // 5. Verify it matches
        XCTAssertEqual(decryptedString, plaintext, "Decrypted text should match original plaintext")
    }
}
