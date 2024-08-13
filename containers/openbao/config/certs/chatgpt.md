To self-sign a TLS certificate and create the necessary `full-chain.pem` and `private-key.pem` files for your Vault (or OpenBao) configuration, you can use OpenSSL. Here’s a step-by-step guide to generate these certificates:

### Step 1: Install OpenSSL
If you don’t already have OpenSSL installed, you can install it using your package manager:

- **On Ubuntu/Debian:**
  ```bash
  sudo apt-get install openssl
  ```
- **On macOS (using Homebrew):**
  ```bash
  brew install openssl
  ```

### Step 2: Generate a Private Key
First, generate a private key. This key will be used to sign the certificate.

```bash
openssl genpkey -algorithm RSA -out private-key.pem -aes256
```

- **`-algorithm RSA`**: Specifies that the key should be generated using the RSA algorithm.
- **`-out private-key.pem`**: Specifies the output file for the private key.
- **`-aes256`**: Encrypts the private key with AES-256, which will require a password to access. You can omit this if you prefer an unencrypted key (not recommended).

### Step 3: Create a Certificate Signing Request (CSR)
Next, create a CSR, which is used to request a certificate from a Certificate Authority (CA). Since we’re self-signing, the CA will be your own system.

```bash
openssl req -new -key private-key.pem -out cert.csr
```

You will be prompted to enter information such as Country, State, Common Name (which should be the fully qualified domain name (FQDN) of your server), etc.

### Step 4: Generate the Self-Signed Certificate
Now, generate the self-signed certificate using the CSR and the private key.

```bash
openssl x509 -req -days 365 -in cert.csr -signkey private-key.pem -out full-chain.pem
```

- **`-days 365`**: Specifies that the certificate is valid for 365 days. Adjust as needed.
- **`-signkey private-key.pem`**: Uses the private key to sign the certificate.
- **`-out full-chain.pem`**: Specifies the output file for the self-signed certificate, which will act as the full chain in this case.

### Step 5: Combine Certificates if Needed
If you had intermediate certificates (not applicable in this self-sign scenario), you would combine them into the `full-chain.pem` file. However, with self-signed certificates, the certificate itself is sufficient.

### Step 6: Verify the Certificate and Key
It’s a good idea to verify that the certificate and private key match.

```bash
openssl x509 -noout -modulus -in full-chain.pem | openssl md5
openssl rsa -noout -modulus -in private-key.pem | openssl md5
```

The output from both commands should be identical.

### Step 7: Configure Vault (or OpenBao)
Use the generated `full-chain.pem` and `private-key.pem` in your Vault or OpenBao `config.hcl`:

```hcl
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_cert_file = "/path/to/full-chain.pem"
  tls_key_file  = "/path/to/private-key.pem"
}
```

### Summary
You’ve now generated a self-signed certificate and private key for use with Vault or OpenBao. This process is useful for testing or internal environments where using a public Certificate Authority (CA) is not necessary.