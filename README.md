# 💨 MQTT mTLS Secure System

This project implements a high-security MQTT communication system using **MQTT 5.0**, **Mutual TLS (mTLS)**, and **Certificate Pinning**. 

## Resources
[A Deep Dive into EMQX with mTLS](https://medium.com/@anupshresth9/a-deep-dive-into-emqx-with-mtls-69ad9aff11e0)

---

## 🛠 Prerequisites

* **Docker & Docker Compose** (for EMQX Broker)
* **OpenSSL** (for certificate generation)
* **Xcode 15+** (for iOS App)

---

## 🏗 Step 1: Generate Security Certificates

Run the provided `generate_certs.sh` script to create the Public Key Infrastructure (PKI). This script generates the CA, Server, and Client certificates required for a "Highest Security" tier.

```bash
chmod +x generate_certs.sh
./generate_certs.sh
```

**Key Files Generated:**

| File | Destination | Purpose |
| :--- | :--- | :--- |
| **ca-cert.der** | Xcode Project | Binary CA used for **Certificate Pinning**. |
| **client.p12** | Xcode Project | Bundled Identity for **mTLS** (Pass: `123456`). |
| **ca-cert.pem** | EMQX Server | The Root CA for the broker. |
| **server-cert.pem** | EMQX Server | The broker's signed certificate. |
| **server-key.pem** | EMQX Server | The broker's private key. |

## 🐳 Step 2: Configure & Run EMQX Broker
- Map the certs: Ensure the .pem files are in a folder named certs relative to your docker-compose.yml.
- Start the Broker:
    ```Bash
    docker-compose up -d
    ```
- Verify Listeners:
    - Open the Dashboard: http://localhost:18083 (User: admin, Pass: public).
    - Go to Management > Listeners.
    - Ensure the ssl:default listener is running on port 8883.

## 📱 Step 3: Configure the iOS Application
- Install Dependencies
    - Go to `MQTT-mTLS-iOS-PoC` folder and open `MQTT-mTLS-POC.xcodeproj` file
    - Install dependencies by `File -> Packages -> Reset Package Caches`
- Import Certificates: Drag and drop `ca-cert.der` and `client.p12` into your Xcode Project Navigator.
    - Target Membership: Ensure the checkbox for your App Target is checked for both files.
    - Build Phases: Verify they appear in Copy Bundle Resources.
- App Transport Security (ATS): in your `info.plist` file add:
    - App Transport Security Settings (Dictionary)
        - Allow Local Networking: YES (Boolean)
- Run the app making sure that you are using correct password to extract the *.p12* file

## 🔍 Step 4: Crisis Management (Security Leak)
If the ca-key.pem is compromised (leaked or stolen):
- Revoke Trust: Immediately stop the EMQX broker.
- Rotate CA: Delete the old certs/ folder and re-run ./generate_certs.sh.
- Update Broker: Replace the .pem files on the server and restart Docker.
- Update Clients: You must push a new build of the iOS app with the new ca-cert.der and client.p12. Because of Strict Pinning, the old app versions will automatically stop connecting to the compromised environment.

## 📝 Troubleshooting
| Error | Cause | Solution |
| :--- | :--- | :--- |
| **Error -9807** | Hostname mismatch or ATS block. | Set **Allow Local Networking** to YES and ensure `host` matches Cert CN. |
| **Error -9825** | Handshake failure. | Check if EMQX listener **8883** is active and reachable. |
| **P12 Error** | Wrong password or missing file. | Ensure password is `123456` in `getMTLSSettings()`. |
| **FATAL: ca-cert.der** | File missing from Bundle. | Check **Target Membership** in Xcode sidebar. |