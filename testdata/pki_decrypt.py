# Independent PKI decryption with the cryptography library (run with /usr/bin/python3, which has it):
# key = SHA-256(X25519(private, peer public)), AES-256-CCM (8-byte tag), firmware nonce
# id (LE) | extraNonce (LE) | from (LE) | 0, encrypted = ciphertext | tag | extraNonce.
# Usage: pki_decrypt.py <private b64> <peer public b64> <packet id> <from> <encrypted hex>  -> plaintext hex
import sys, base64, struct, hashlib
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey, X25519PublicKey
from cryptography.hazmat.primitives.ciphers.aead import AESCCM
priv, peer, pid, frm, enc = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), bytes.fromhex(sys.argv[5])
shared = X25519PrivateKey.from_private_bytes(base64.b64decode(priv)).exchange(X25519PublicKey.from_public_bytes(base64.b64decode(peer)))
key = hashlib.sha256(shared).digest()
extra = struct.unpack("<I", enc[-4:])[0]
nonce = (struct.pack("<I", pid) + struct.pack("<I", extra) + struct.pack("<I", frm) + bytes(4))[:13]
print(AESCCM(key, tag_length=8).decrypt(nonce, enc[:-4], None).hex())
