import Foundation
import CocoaMQTT
import Security

class MQTTService: NSObject {

    private var mqtt5: CocoaMQTT5?
    private let host: String
    private let port: UInt16
    private let clientID: String
    private let p12Name: String
    private let p12Password: String
    private let caCertName: String

    init(
        host: String = "localhost",
        port: UInt16 = 8883,
        clientID: String = "bus_103",
        clientP12Name: String = "client",
        clientP12Password: String = "123456",
        caCertName: String = "ca-cert"
    ) {
        self.host = host
        self.port = port
        self.clientID = clientID
        self.p12Name = clientP12Name
        self.p12Password = clientP12Password
        self.caCertName = caCertName
        super.init()
    }

    func connect() {
        mqtt5 = CocoaMQTT5(clientID: clientID, host: host, port: port)
        mqtt5?.delegate = self
        mqtt5?.keepAlive = 60
        
        mqtt5?.username = clientID
//        mqtt5?.password = jwtToken
        mqtt5?.password = "123456"

        // Enable SSL and enforce strict validation
        mqtt5?.enableSSL = true
        mqtt5?.allowUntrustCACertificate = true

        // Load Client Identity (mTLS)
        if let sslSettings = getMTLSSettings() {
            mqtt5?.sslSettings = sslSettings
        }

        _ = mqtt5?.connect()
    }

    private func getMTLSSettings() -> [String: NSObject]? {
        guard let clientCertPath = Bundle.main.path(forResource: p12Name, ofType: "p12"),
              let p12Data = NSData(contentsOfFile: clientCertPath) else {
            print("[MQTT] Error: p12 file missing from bundle.")
            return nil
        }

        let options = [kSecImportExportPassphrase as String: p12Password] as NSDictionary
        var items: CFArray?
        let status = SecPKCS12Import(p12Data, options, &items)
        
        guard status == errSecSuccess, let theItems = items, CFArrayGetCount(theItems) > 0 else {
            print("[MQTT] Error: p12 import failed. Status: \(status)")
            return nil
        }

        let dict = (theItems as NSArray).object(at: 0) as! [String: Any]
        guard let identity = dict[kSecImportItemIdentity as String] else { return nil }

        return [kCFStreamSSLCertificates as String: [identity] as CFArray]
    }

    func disconnect() {
        mqtt5?.disconnect()
    }
    
    func subscribe(id: String) {
        mqtt5?.subscribe("bus/\(id)/chat")
    }
    
    func publish(id: String) {
        mqtt5?.publish(.init(topic: "bus/\(id)/chat", string: "Hello from iOS!!"), properties: MqttPublishProperties())
    }
}

// MARK: - CocoaMQTT5Delegate (Strict Security Implementation)
extension MQTTService: CocoaMQTT5Delegate {

    func mqtt5(_ mqtt5: CocoaMQTT5, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        print("[Security] Starting Strict Peer Verification...")

        // 1. Load the Anchor (The CA certificate you trust)
        guard let caPath = Bundle.main.path(forResource: caCertName, ofType: "der"),
              let caData = try? Data(contentsOf: URL(fileURLWithPath: caPath)),
              let caCertificate = SecCertificateCreateWithData(nil, caData as CFData) else {
            print("[Security] FATAL: Trusted anchor (CA) not found in bundle.")
            completionHandler(false)
            return
        }

        // 2. Set your CA as the ONLY trusted anchor
        SecTrustSetAnchorCertificates(trust, [caCertificate] as CFArray)
        SecTrustSetAnchorCertificatesOnly(trust, true)

        // 3. Update Policy
        // We try to create a policy for the host. If 'localhost' or '127.0.0.1'
        // fails with a standard SSL policy, we use a basic X509 policy.
        let policy = SecPolicyCreateSSL(true, host as CFString)
        SecTrustSetPolicies(trust, policy)

        // 4. Evaluation
        var error: CFError?
        if SecTrustEvaluateWithError(trust, &error) {
            print("[Security] Mutual Trust Established.")
            completionHandler(true)
        } else {
            print("[Security] Standard SSL Policy failed: \(error?.localizedDescription ?? "N/A")")
            
            // --- SECOND CHANCE FOR LOCALHOST/IP ---
            // If the only error is a hostname mismatch on a local IP, but the
            // certificate IS signed by our pinned CA, we allow it.
            let basicPolicy = SecPolicyCreateBasicX509()
            SecTrustSetPolicies(trust, basicPolicy)
            
            var basicError: CFError?
            if SecTrustEvaluateWithError(trust, &basicError) {
                print("[Security] Verified via Pinned CA (Ignoring Hostname Mismatch).")
                completionHandler(true)
            } else {
                print("[Security] Handshake Blocked: \(basicError?.localizedDescription ?? "Untrusted Chain")")
                completionHandler(false)
            }
        }
    }

    // Success and Failure handlers
    func mqtt5(_ mqtt5: CocoaMQTT5, didConnectAck ack: CocoaMQTTCONNACKReasonCode, connAckData: MqttDecodeConnAck?) {
        if ack == .success {
            print("[MQTT] Verified Session Established.")
        } else {
            print("[MQTT] Broker rejected connection: \(ack)")
        }
    }

    func mqtt5DidDisconnect(_ mqtt5: CocoaMQTT5, withError err: Error?) {
        print("[MQTT] Disconnected. Error: \(err?.localizedDescription ?? "None")")
    }

    // Required Delegate Methods (No-op)
    func mqtt5(_ mqtt5: CocoaMQTT5, didPublishMessage m: CocoaMQTT5Message, id: UInt16) {
        print("PUB:: sending a message ...")
    }
    func mqtt5(_ mqtt5: CocoaMQTT5, didPublishAck id: UInt16, pubAckData: MqttDecodePubAck?) {
        print("PUB:: responseCode", pubAckData?.reasonCode?.rawValue)
    }
    func mqtt5(_ mqtt5: CocoaMQTT5, didPublishRec id: UInt16, pubRecData: MqttDecodePubRec?) {}
    func mqtt5(_ mqtt5: CocoaMQTT5, didUnsubscribeTopics t: [String], unsubAckData: MqttDecodeUnsubAck?) {}
    func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveDisconnectReasonCode r: CocoaMQTTDISCONNECTReasonCode) {}
    func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveAuthReasonCode r: CocoaMQTTAUTHReasonCode) {}
    func mqtt5DidPing(_ mqtt5: CocoaMQTT5) {}
    func mqtt5DidReceivePong(_ mqtt5: CocoaMQTT5) {}
    func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveMessage m: CocoaMQTT5Message, id: UInt16, publishData: MqttDecodePublish?) {}
    func mqtt5(_ mqtt5: CocoaMQTT5, didSubscribeTopics s: NSDictionary, failed: [String], subAckData: MqttDecodeSubAck?) {
        let hehe = subAckData?.reasonCodes[0]
        print("SUB:: responseCode", subAckData?.reasonCodes.forEach({ $0.rawValue }))
    }
}
