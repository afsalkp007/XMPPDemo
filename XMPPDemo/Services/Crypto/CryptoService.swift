import Foundation
import CryptoKit
import Security

enum CryptoError: Error {
    case secureEnclaveUnavailable
    case keyGenerationFailed
    case missingPublicKey
    case encryptionFailed
    case decryptionFailed
}

final class CryptoService: Sendable {
    static let shared = CryptoService()
    
    private let keyTag = "com.xmppdemo.e2ee.privatekey".data(using: .utf8)!
    
    private init() {}
    
    // MARK: - Key Management
    
    private func getSecureEnclavePrivateKey() throws -> SecureEnclave.P256.KeyAgreement.PrivateKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data {
            do { return try SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: data) } catch { }
        }
        
        let privateKey = try SecureEnclave.P256.KeyAgreement.PrivateKey()
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag,
            kSecValueData as String: privateKey.dataRepresentation,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(addQuery as CFDictionary, nil)
        return privateKey
    }
    
    private func getSoftwarePrivateKey() throws -> P256.KeyAgreement.PrivateKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data {
            do { return try P256.KeyAgreement.PrivateKey(rawRepresentation: data) } catch { }
        }
        
        let privateKey = P256.KeyAgreement.PrivateKey()
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag,
            kSecValueData as String: privateKey.rawRepresentation,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(addQuery as CFDictionary, nil)
        return privateKey
    }
    
    private func computeSharedSecret(with publicKey: P256.KeyAgreement.PublicKey) throws -> SharedSecret {
        if SecureEnclave.isAvailable {
            return try getSecureEnclavePrivateKey().sharedSecretFromKeyAgreement(with: publicKey)
        } else {
            return try getSoftwarePrivateKey().sharedSecretFromKeyAgreement(with: publicKey)
        }
    }
    
    /// Returns the raw Base64 representation of the user's public key
    func getMyPublicKeyBase64() throws -> String {
        if SecureEnclave.isAvailable {
            return try getSecureEnclavePrivateKey().publicKey.rawRepresentation.base64EncodedString()
        } else {
            return try getSoftwarePrivateKey().publicKey.rawRepresentation.base64EncodedString()
        }
    }
    
    // MARK: - Encryption / Decryption
    
    /// Encrypts a message payload for a specific recipient using ECDH + AES-GCM
    func encrypt(payload: Data, recipientPublicKeyBase64: String) throws -> (ciphertext: String, nonce: String) {
        guard let pubKeyData = Data(base64Encoded: recipientPublicKeyBase64) else {
            throw CryptoError.missingPublicKey
        }
        
        let recipientPublicKey = try P256.KeyAgreement.PublicKey(rawRepresentation: pubKeyData)
        
        // 1. ECDH Key Agreement
        let sharedSecret = try computeSharedSecret(with: recipientPublicKey)
        
        // 2. HKDF Key Derivation
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("xmppdemo-e2ee".utf8),
            outputByteCount: 32
        )
        
        // 3. AES-GCM Encryption
        let sealedBox = try AES.GCM.seal(payload, using: symmetricKey)
        
        guard let ciphertext = sealedBox.combined?.base64EncodedString() else {
            throw CryptoError.encryptionFailed
        }
        
        // We can just use the combined representation (nonce + ciphertext + tag)
        return (ciphertext: ciphertext, nonce: "")
    }
    
    /// Decrypts a message payload from a specific sender using ECDH + AES-GCM
    func decrypt(combinedBase64: String, senderPublicKeyBase64: String) throws -> Data {
        guard let pubKeyData = Data(base64Encoded: senderPublicKeyBase64),
              let combinedData = Data(base64Encoded: combinedBase64) else {
            throw CryptoError.missingPublicKey
        }
        
        let senderPublicKey = try P256.KeyAgreement.PublicKey(rawRepresentation: pubKeyData)
        
        // 1. ECDH Key Agreement
        let sharedSecret = try computeSharedSecret(with: senderPublicKey)
        
        // 2. HKDF Key Derivation
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("xmppdemo-e2ee".utf8),
            outputByteCount: 32
        )
        
        // 3. AES-GCM Decryption
        let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
        
        return decryptedData
    }
}
