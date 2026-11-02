# Recursos — sys-20

## Documentación oficial

- **`wget(1)` manual** — <https://www.gnu.org/software/wget/manual/wget.html>
- **`curl(1)` manual** — <https://curl.se/docs/manpage.html>
- **GNU coreutils — `sha256sum`** — <https://www.gnu.org/software/coreutils/manual/html_node/sha2-utilities.html>
- **GnuPG Handbook (Gpg4win manual, aplicable a GnuPG en Linux)** — <https://gnupg.org/documentation/manuals/gnupg/>
- **GnuPG — `gpg --verify`** — <https://gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html>

## Supply chain / reproducible builds

- **Reproducible Builds** — <https://reproducible-builds.org/>
- **Debian SecureApt** (modelo de repos firmados) — <https://wiki.debian.org/SecureApt>
- **in-toto / SLSA** (framework de supply chain security) — <https://slsa.dev/>
- **Sigstore / cosign** (firma moderna sin keyservers tradicionales) — <https://www.sigstore.dev/>

## Lecturas de contexto

- **Tor Project — verifying signatures** (ejemplo real de flujo GPG) — <https://support.torproject.org/tbb/how-to-verify-signature/>
- **Debian — detached signatures how-to** — <https://wiki.debian.org/SecureApt#How_to_check_a_signature_with_gpg>
- **xkcd 2347 — "Dependency"** (contexto cultural de supply chain) — <https://xkcd.com/2347/>

## Herramientas útiles

- **`shellcheck`** — <https://www.shellcheck.net/> (requerido para la rúbrica).
- **`b3sum`** (BLAKE3, alternativa a SHA-256 cuando el publisher la ofrece) — <https://github.com/BLAKE3-team/BLAKE3>

## Nota de verificación

Última verificación de enlaces: pendiente de validar en Fase 4 (lecciones ejecutables). Todos los enlaces son dominios oficiales (`gnu.org`, `gnupg.org`, `curl.se`, `reproducible-builds.org`, `debian.org`, `slsa.dev`, `sigstore.dev`); verificar fecha y disponibilidad al momento de desarrollar el curso en producción.
