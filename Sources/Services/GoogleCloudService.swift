import Foundation
import CryptoKit

public class GoogleCloudService {
    private let session: URLSession
    private let credentials: [String: Any]
    private let baseVideoURL = "https://videointelligence.googleapis.com/v1"
    private let baseSpeechURL = "https://speech.googleapis.com/v1"
    private let baseLanguageURL = "https://language.googleapis.com/v1"
    private let tokenURL = "https://oauth2.googleapis.com/token"
    private let scope = "https://www.googleapis.com/auth/cloud-platform"
    
    private var cachedToken: String?
    private var tokenExpiration: Date?
    
    private static func findCredentialsPath(for type: GoogleCloudService.Type) -> String? {
        if let frameworkPath = Bundle(for: type).path(forResource: "dwell-app-8cfa8-de4ec234f734", ofType: "json") {
            return frameworkPath
        }
        return Bundle.main.path(forResource: "dwell-app-8cfa8-de4ec234f734", ofType: "json")
    }
    
    public init() throws {
        self.session = URLSession(configuration: .default)
        
        guard let credentialsPath = Self.findCredentialsPath(for: GoogleCloudService.self),
              let credentials = try? Data(contentsOf: URL(fileURLWithPath: credentialsPath)),
              let json = try? JSONSerialization.jsonObject(with: credentials) as? [String: Any],
              let projectId = json["project_id"] as? String,
              let privateKey = json["private_key"] as? String,
              let clientEmail = json["client_email"] as? String else {
            throw NSError(domain: "GoogleCloudService", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to load service account credentials"])
        }
        
        self.credentials = json
    }
    
    private func createJWT() throws -> String {
        guard let privateKey = credentials["private_key"] as? String,
              let clientEmail = credentials["client_email"] as? String else {
            throw NSError(domain: "GoogleCloudService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Missing required credentials"])
        }
        
        let header = [
            "alg": "RS256",
            "typ": "JWT"
        ]
        
        let now = Date()
        let exp = now.addingTimeInterval(3600) // 1 hour from now
        
        let claims = [
            "iss": clientEmail,
            "scope": scope,
            "aud": "https://oauth2.googleapis.com/token",
            "exp": Int(exp.timeIntervalSince1970),
            "iat": Int(now.timeIntervalSince1970)
        ] as [String : Any]
        
        // Encode header and claims
        let headerData = try JSONSerialization.data(withJSONObject: header)
        let claimsData = try JSONSerialization.data(withJSONObject: claims)
        
        let headerBase64 = headerData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        let claimsBase64 = claimsData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        let signatureInput = "\(headerBase64).\(claimsBase64)"
        
        // Remove header and footer from private key
        let cleanPrivateKey = privateKey
            .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----\n", with: "")
            .replacingOccurrences(of: "\n-----END PRIVATE KEY-----\n", with: "")
        
        guard let keyData = Data(base64Encoded: cleanPrivateKey) else {
            throw NSError(domain: "GoogleCloudService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid private key format"])
        }
        
        let signatureData = try signatureInput.data(using: .utf8)!
        
        // Use SecKey for RSA signing
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateSecKey = SecKeyCreateWithData(keyData as CFData,
                                                     attributes as CFDictionary,
                                                     &error) else {
            throw error?.takeRetainedValue() ?? NSError(domain: "GoogleCloudService", code: -1,
                                                       userInfo: [NSLocalizedDescriptionKey: "Failed to create private key"])
        }
        
        var signedData: Data?
        if let blockData = signatureData as CFData? {
            signedData = SecKeyCreateSignature(privateSecKey,
                                             .rsaSignatureMessagePKCS1v15SHA256,
                                             blockData,
                                             &error) as Data?
        }
        
        guard let signature = signedData else {
            throw error?.takeRetainedValue() ?? NSError(domain: "GoogleCloudService", code: -1,
                                                       userInfo: [NSLocalizedDescriptionKey: "Failed to create signature"])
        }
        
        let signatureBase64 = signature.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        return "\(headerBase64).\(claimsBase64).\(signatureBase64)"
    }
    
    private func getAccessToken() async throws -> String {
        // Check if we have a valid cached token
        if let token = cachedToken,
           let expiration = tokenExpiration,
           expiration > Date().addingTimeInterval(300) { // 5 minutes buffer
            return token
        }
        
        let jwt = try createJWT()
        
        let body = [
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": jwt
        ]
        
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, _) = try await session.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String,
              let expiresIn = json["expires_in"] as? TimeInterval else {
            throw NSError(domain: "GoogleCloudService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid token response"])
        }
        
        // Cache the token
        cachedToken = accessToken
        tokenExpiration = Date().addingTimeInterval(expiresIn)
        
        return accessToken
    }
    
    private func authorizedRequest(url: URL) async throws -> URLRequest {
        var request = URLRequest(url: url)
        let token = try await getAccessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    
    // Video Analysis
    public func analyzeVideo(url: URL) async throws -> VideoAnalysisResult {
        let videoData = try Data(contentsOf: url)
        let base64Video = videoData.base64EncodedString()
        
        let requestBody: [String: Any] = [
            "inputContent": base64Video,
            "features": [
                "LABEL_DETECTION",
                "SHOT_CHANGE_DETECTION",
                "SPEECH_TRANSCRIPTION"
            ]
        ]
        
        let endpoint = "\(baseVideoURL)/videos:annotate"
        var request = try await authorizedRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await session.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // Process response and create VideoAnalysisResult
        // This is a simplified version - you'll need to parse the actual response format
        return VideoAnalysisResult(scenes: [], transcript: "Transcript from video", qualityIssues: [])
    }
    
    // Speech to Text
    public func transcribeAudio(url: URL) async throws -> String {
        let audioData = try Data(contentsOf: url)
        let base64Audio = audioData.base64EncodedString()
        
        let requestBody: [String: Any] = [
            "audio": ["content": base64Audio],
            "config": [
                "encoding": "LINEAR16",
                "sampleRateHertz": 16000,
                "languageCode": "en-US",
                "enableAutomaticPunctuation": true
            ]
        ]
        
        let endpoint = "\(baseSpeechURL)/speech:recognize"
        var request = try await authorizedRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await session.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // Process response and extract transcript
        // This is a simplified version - you'll need to parse the actual response format
        return "Transcribed text"
    }
    
    // Content Analysis and Generation
    public func analyzeContent(text: String) async throws -> LanguageAnalysis {
        let requestBody: [String: Any] = [
            "document": [
                "type": "PLAIN_TEXT",
                "content": text
            ],
            "encodingType": "UTF8"
        ]
        
        let endpoint = "\(baseLanguageURL)/documents:analyzeSentiment"
        var request = try await authorizedRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await session.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // Process response and create LanguageAnalysis
        // This is a simplified version - you'll need to parse the actual response format
        return LanguageAnalysis(score: 0.5, magnitude: 1.0)
    }
}

// Result types
public struct VideoAnalysisResult {
    public let scenes: [Scene]
    public let transcript: String
    public let qualityIssues: [String]
}

public struct LanguageAnalysis {
    public let score: Float
    public let magnitude: Float
} 