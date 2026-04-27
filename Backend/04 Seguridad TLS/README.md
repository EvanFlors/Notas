# Módulo 04 — Seguridad: TLS y Criptografía

## Propósito

Todo tráfico en producción va sobre TLS. Entender el handshake te permite diagnosticar problemas de latencia, certificados, y seguridad. La criptografía aplicada es la base de autenticación, integridad de datos, y secretos.

## Temas

| Archivo | Tema | Conceptos clave |
|---------|------|-----------------|
| 4.1 | Criptografía aplicada | Symmetric/asymmetric, hashing, HMAC, key derivation |
| 4.2 | TLS | TLS 1.2/1.3, certificados X.509, PKI, mTLS |
| 4.3 | Rutas de HTTPS | Latencia de TCP+TLS, QUIC 0-RTT, TCP Fast Open |

## Dependencias

```
Módulo 2 (TCP) + Módulo 3 (HTTP) → Módulo 4 (TLS sobre TCP, HTTPS)
                                  → Módulo 10 (Seguridad Backend)
```
