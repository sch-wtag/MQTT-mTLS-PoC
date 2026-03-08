#!/bin/bash

# 1. Setup Directory
mkdir -p certs
cd certs

echo "Generating High-Security certificates for EMQX and iOS..."

# ---------------------------------------------------------
# 2. Generate Certificate Authority (CA)
# ---------------------------------------------------------
openssl genrsa -out ca-key.pem 4096
openssl req -new -x509 -days 3650 -key ca-key.pem -sha256 -out ca-cert.pem \
    -subj "/C=BD/ST=CTG/L=Chittagong/O=WellDev/OU=Innotix/CN=MyLocalCA"

# NEW: Convert CA to DER format for iOS strict pinning
openssl x509 -in ca-cert.pem -outform der -out ca-cert.der

# ---------------------------------------------------------
# 3. Generate Server Certificate (EMQX Broker)
# ---------------------------------------------------------
openssl genrsa -out server-key.pem 4096
openssl req -new -key server-key.pem -out server.csr \
    -subj "/C=BD/ST=CTG/L=Chittagong/O=WellDev/OU=Innotix/CN=localhost"

# UPDATED: Added IP as DNS for better iOS matching compatibility
cat > server-extfile.cnf <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = emqx
DNS.3 = 127.0.0.1
IP.1 = 127.0.0.1
IP.2 = 172.21.0.2
EOF

openssl x509 -req -in server.csr -CA ca-cert.pem -CAkey ca-key.pem \
    -CAcreateserial -out server-cert.pem -days 365 -sha256 -extfile server-extfile.cnf

# ---------------------------------------------------------
# 4. Generate Client Certificate (iOS App mTLS)
# ---------------------------------------------------------
openssl genrsa -out client-key.pem 4096
openssl req -new -key client-key.pem -out client.csr \
    -subj "/C=BD/ST=CTG/L=Chittagong/O=WellDev/OU=Innotix/CN=iOSClient"

echo "extendedKeyUsage = clientAuth" > client-extfile.cnf

openssl x509 -req -in client.csr -CA ca-cert.pem -CAkey ca-key.pem \
    -CAcreateserial -out client-cert.pem -days 365 -sha256 -extfile client-extfile.cnf

# ---------------------------------------------------------
# 5. Export to .p12 for iOS Identity
# ---------------------------------------------------------
echo "Exporting client.p12..."
openssl pkcs12 -export -out client.p12 \
    -inkey client-key.pem \
    -in client-cert.pem \
    -certfile ca-cert.pem \
    -passout pass:123456

# ---------------------------------------------------------
# 6. Cleanup and Permissions
# ---------------------------------------------------------
rm server.csr client.csr server-extfile.cnf client-extfile.cnf
chmod 644 *.pem *.p12 *.der

echo "---------------------------------------------------------"
echo "Success! Certificates are ready."
echo "---------------------------------------------------------"
echo "FOR EMQX (Docker):"
echo "  - ca-cert.pem, server-cert.pem, server-key.pem"
echo ""
echo "FOR iOS APP (Xcode Bundle):"
echo "  - client.p12 (Password: 123456)"
echo "  - ca-cert.der (Use this for SecCertificate pinning)"
echo "---------------------------------------------------------"
