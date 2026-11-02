# sys-20 — Teoría: descarga reproducible y verificación de integridad

> Objetivo de la lección: convertir "bajar un archivo" en una operación **reproducible, resiliente y verificable**, no en un acto de fe.

---

## 1. Por qué "bajar un archivo" no es trivial

Un `wget https://ejemplo.com/tool.tar.gz` cualquiera parece inocente, pero mete al menos cinco supuestos silenciosos:

1. El DNS resolvió al host correcto.
2. La red llegó al host sin que nadie en el medio modificara los bytes.
3. El servidor TLS presenta un certificado válido para ese host.
4. El contenido servido es el que el autor publicó, no una versión manipulada por alguien que comprometió el servidor.
5. Si la descarga se corta, podemos retomarla sin terminar con un archivo truncado invisible.

TLS cubre (2) y parcialmente (3). **No** cubre (4): si el servidor fue comprometido, TLS entrega con integridad perfecta un binario malicioso. Y nada en TLS garantiza (5).

De ahí los dos ejes de este módulo:

- **Resiliencia de red** → `wget` con flags de retry/resume/timeout.
- **Integridad y autenticidad** → `sha256sum --check` y `gpg --verify`.

---

## 2. `wget` vs `curl`: cuándo cada uno

Son herramientas distintas con solapamiento engañoso. Elegir mal convierte un script simple en un enredo.

| Dimensión | `wget` | `curl` |
|-----------|--------|--------|
| Caso central | **Descargar archivos** a disco | Hablar con **APIs HTTP** (JSON, headers, verbos) |
| Resume de descargas | `-c` (nativo, excelente) | `-C -` (funciona, pero menos ergonómico) |
| Reintentos automáticos | `--tries=N --retry-connrefused --waitretry=S` (nativos) | Manual (bucle) o `--retry` (más limitado) |
| Mirror recursivo | `-m`, `-r`, `--mirror` (nativo) | No existe |
| Métodos no-GET | Limitado | Nativo (`-X POST`, `-X PUT`, …) |
| Streaming a stdout | Posible (`-O -`) pero no es su ergonomía | Nativo (`curl URL`) |
| Headers arbitrarios | Posible (`--header`) | Nativo (`-H`), ergonomía mejor |
| Salida por defecto | A archivo | A stdout |

Heurística operativa:

- **Vas a guardar un artefacto grande, posiblemente con red flaky, y querés poder reanudar** → `wget`.
- **Vas a hablar con una API, mandar headers, inspeccionar status codes, hacer POST** → `curl`.

En este módulo usamos `wget` para el fetch del artefacto porque `-c` y `--tries` son el camino más corto a *descarga robusta*. `curl` aparece sólo en el contexto de "por qué `curl … | bash` es malo".

---

## 3. Flags de `wget` que importan

### 3.1 `-c` — continuar una descarga parcial

Si el archivo local existe y es más corto que el remoto, `wget` manda un `Range:` y reanuda. Si el remoto no soporta `Range`, cae a descarga completa. **Clave en redes inestables.**

Trampa: `-c` **no verifica** que el prefijo local coincida con el remoto. Si cambió el archivo upstream, terminás con un Frankenstein. Por eso un pipeline serio verifica el checksum **después** del resume.

### 3.2 `-O archivo` — forzar nombre de salida

Útil cuando la URL redirige o cuando el nombre importa en el pipeline. Combinado con `-c`, exige pensar: si el archivo preexiste con otro contenido, lo trunca o lo retoma según la combinación.

### 3.3 `--tries=N`

Número total de intentos ante error de red. `0` = infinito (no lo uses en producción: no fallar es peor que fallar). Un número finito (5–10) con `--waitretry` es sano.

### 3.4 `--timeout=S` / `--connect-timeout=S` / `--read-timeout=S`

`--timeout` setea los tres (DNS, connect, read). En práctica, uno quiere **leer explícito**: `--connect-timeout=10 --read-timeout=30`. Un script sin timeouts se cuelga indefinidamente ante un peer que acepta la conexión y no manda bytes.

### 3.5 `--retry-connrefused`

Por default, `wget` **no** reintenta ante `ECONNREFUSED` (asume "no hay servidor, no tiene sentido reintentar"). Con `--retry-connrefused`, sí. Útil cuando el servidor acaba de arrancar y aún no bindeó el puerto (deploys, boot de contenedores).

### 3.6 `--waitretry=S`

Espera entre reintentos, lineal creciente hasta `S`. Útil para no martillar un servidor que ya está en apuros. Pseudo-backoff.

### 3.7 `--no-check-certificate` (y por qué **nunca**)

Desactiva verificación de certificado TLS. En práctica reduce TLS a cifrado contra escuchas pasivas, pero deja la puerta abierta a MITM activo con cert propio. **Nunca debería aparecer en producción.** Si falla la verificación, lo que hay que arreglar es el almacén de CAs del sistema, no silenciar el chequeo.

Equivalente en `curl`: `-k` / `--insecure`. Misma regla.

### 3.8 Mirror `-m` (o `-r --mirror`)

Baja recursivamente respetando `robots.txt` y timestamps. Caso de uso: *tomar un snapshot de un sitio estático*. Casi nunca es lo que querés para descargar un artefacto puntual; se usa mal como "bajar directorio entero" y termina generando problemas (links reescritos, archivos duplicados, cargas al servidor).

---

## 4. Estrategia de retry y backoff

Un script serio no se limita a `--tries=5`. Pensá en tres ejes:

1. **Qué errores reintentar.** DNS fallido, connect timeout, 5xx: sí. 4xx (`401`, `403`, `404`): **no** — el servidor te está diciendo algo informativo, reintentar no cambia la respuesta.
2. **Cuánto esperar entre intentos.** Backoff creciente (`--waitretry`) evita martillear. Para pipelines, un patrón razonable: `--tries=5 --waitretry=10 --timeout=30`.
3. **Qué hacer cuando se agotan.** Exit code **no-cero** semántico, log claro con URL, mensaje de error del último intento. Nunca `exit 0` encubriendo un fallo (le mentís al orquestador que te invocó).

Patrón bash típico (lo verás en las actividades):

```bash
set -euo pipefail
wget --continue \
     --tries=5 \
     --timeout=30 \
     --waitretry=10 \
     --retry-connrefused \
     -O "$out" "$url" \
  || { echo "ERROR: fetch de $url falló tras 5 intentos" >&2; exit 69; }
```

Exit code `69` es `EX_UNAVAILABLE` de `sysexits.h`: "servicio no disponible". Un orquestador puede reaccionar distinto a esto que a `2` (uso incorrecto) o `1` (error genérico).

---

## 5. Checksums: qué resuelven y qué no

### 5.1 El idioma

Un **hash criptográfico** (SHA-256, SHA-512, BLAKE2) toma bytes arbitrarios y produce una huella de tamaño fijo con dos propiedades operativas:

- **Resistencia a preimagen:** dado un hash, es inviable construir un contenido que lo produzca.
- **Resistencia a colisión:** es inviable encontrar dos contenidos distintos con el mismo hash.

SHA-1 **ya no** cumple (2) en la práctica (Shattered, 2017). Para artefactos nuevos: **SHA-256 mínimo**, SHA-512 preferido si el publisher lo ofrece.

### 5.2 El formato estándar `SHA256SUMS`

Convención (coreutils):

```
<hex-hash-64-chars>  <nombre-del-archivo>
```

Dos espacios entre hash y nombre (en modo binario, el separador es ` *`). Un archivo `SHA256SUMS` puede contener muchas líneas. Se verifica así:

```bash
sha256sum --check SHA256SUMS
# Para solo verificar entradas presentes en disco:
sha256sum --check --ignore-missing SHA256SUMS
```

Exit code `0` solo si **todas** las entradas verificadas pasaron. Esto es lo que explotamos en los scripts.

### 5.3 Qué protege un checksum y qué **no**

| Escenario | ¿Checksum ayuda? |
|-----------|------------------|
| Corrupción en tránsito (bit-flip, truncado) | Sí |
| Mirror corrupto por bug del servidor | Sí |
| MITM que reescribe el tarball **pero no** `SHA256SUMS` | Sí |
| Servidor comprometido que reescribe **ambos** | **No** |
| Publisher legítimo que empaquetó malware | **No** |

El punto clave: **un `SHA256SUMS` servido desde el mismo origen que el tarball no es defensa contra el compromiso del origen.** Para eso hace falta **firma** sobre el `SHA256SUMS` con una clave que el atacante no controla.

### 5.4 Walkthrough: verificar una descarga

Supongamos que bajás `tool-1.2.3.tar.gz` y su `SHA256SUMS`:

```bash
# 1. Descargar ambos
wget https://ejemplo.com/tool-1.2.3.tar.gz
wget https://ejemplo.com/tool-1.2.3.tar.gz.sha256   # a veces viene como sidecar

# 2a. Si el sidecar es formato coreutils (hash + nombre):
sha256sum --check tool-1.2.3.tar.gz.sha256

# 2b. Si solo es el hash (sin nombre), construir la línea:
EXPECTED=$(cat tool-1.2.3.tar.gz.sha256 | awk '{print $1}')
ACTUAL=$(sha256sum tool-1.2.3.tar.gz | awk '{print $1}')
if [[ "$EXPECTED" != "$ACTUAL" ]]; then
  echo "MISMATCH: esperado $EXPECTED, obtenido $ACTUAL" >&2
  exit 65   # EX_DATAERR
fi
```

Nunca compares como *strings sueltos* copiando a mano desde un sitio web: usá `--check` siempre que puedas; es el modo auditable.

### 5.5 Publicar tu propio `SHA256SUMS`

Para artefactos que generás vos:

```bash
cd dist/
sha256sum -- *.tar.gz *.zip > SHA256SUMS
```

Y en producción: firmar el `SHA256SUMS` (siguiente sección), no los archivos uno por uno. Es más barato operativamente y suficiente (la firma protege el hash, el hash protege el contenido).

---

## 6. Firmas GPG: autenticidad + integridad

### 6.1 Qué agrega una firma al checksum

Un `SHA256SUMS` responde "¿los bytes son los esperados?". Una firma responde "¿los esperados fueron **declarados** por quien dice haberlos declarado?". Son defensas distintas:

- **Checksum solo:** protege contra corrupción en tránsito y errores de mirror.
- **Firma GPG sobre el checksum:** protege además contra reescritura del checksum por un atacante que controla el servidor de distribución, siempre y cuando el atacante **no** controle la clave privada.

Las dos juntas son el estándar sano en proyectos serios (Debian, GNU, Tor, Signal, kernel).

### 6.2 Flujo típico de verificación

Un publisher serio publica:

- `tool-1.2.3.tar.gz`
- `tool-1.2.3.tar.gz.asc`   (firma detached sobre el tarball)   **o bien**
- `SHA256SUMS` y `SHA256SUMS.asc` (firma sobre el archivo de hashes).

Verificación:

```bash
# 1. Importar la clave pública del publisher (una sola vez)
gpg --recv-keys <KEY-ID>                 # desde un keyserver
# o: gpg --import publisher.pub         # desde un .asc local

# 2. (Fuerte recomendación) marcarla como confiable con nivel apropiado
gpg --edit-key <KEY-ID>
# > trust  → elegir nivel (ver 6.4)
# > quit

# 3. Verificar firma
gpg --verify tool-1.2.3.tar.gz.asc tool-1.2.3.tar.gz
```

Salidas posibles:

- `Good signature from "Nombre <mail>"` + `Primary key fingerprint: ...` → ok.
- `BAD signature` → **abortar**, no es el archivo que fue firmado.
- `WARNING: This key is not certified with a trusted signature!` → la firma matemáticamente es válida, pero vos no has declarado que confías en que esa clave pertenezca a quien dice ser (ver 6.4).

### 6.3 El problema del "primer uso"

¿Cómo sabés que la clave pública que importaste es la real del publisher y no la de un atacante? Dos modelos coexisten:

- **Web of Trust (WoT):** vos ya confiabas en Alice; Alice firmó la clave de Bob; por transitividad podés confiar razonablemente en Bob. Elegante en teoría; en la práctica, poca gente mantiene su WoT.
- **TOFU (Trust On First Use):** aceptás la clave la primera vez y confiás en que no cambie. Es lo que `gpg --auto-key-locate` + `--trust-model tofu` hace. Pragmático; vulnerable si el "primer uso" ya es contra un impostor.

En la vida real, para proyectos serios: la clave se publica en **múltiples canales independientes** (sitio web, repo git, Keybase, keyservers, mención en release notes firmadas por releases anteriores). Verificás el **fingerprint** por al menos dos vías. Esa es la contraseña contra el ataque de "primer uso contra un impostor".

### 6.4 Niveles de confianza en GPG

Cuando hacés `trust` en una clave, elegís:

- `unknown` / `never`: no confío.
- `marginal`: confío parcialmente; necesito varias claves marginales para considerar un path válido.
- `full`: confío plenamente en que esta clave firma lo que dice firmar.
- `ultimate`: solo para tus propias claves.

Un `--verify` sin trust explícito muestra el warning de 6.2 pero devuelve exit code `0` (la firma es matemáticamente válida). Un script serio debe **chequear además el fingerprint** contra una lista conocida, no solo el exit code.

### 6.5 Firma del artefacto vs firma del checksum

- Firmar cada tarball es overhead si hay muchos.
- Firmar un `SHA256SUMS` que lista todos es equivalente en garantías y más barato: alterar un tarball requeriría alterar su hash en `SHA256SUMS`, lo que rompe la firma.

Por eso Debian, GNU y otros firman el "manifiesto".

---

## 7. Escenarios de ataque y qué mitiga cada defensa

| Ataque | TLS | Checksum publicado en mismo host | Firma GPG sobre checksum |
|--------|-----|----------------------------------|--------------------------|
| MITM pasivo (escucha) | Mitiga | Irrelevante | Irrelevante |
| MITM activo (reescribe tráfico, no tiene cert válido) | Mitiga | Mitiga redundante | Mitiga redundante |
| MITM activo con cert forjado (CA comprometida) | **No mitiga** | Mitiga si el atacante no reescribe también el checksum | Mitiga |
| Compromiso del servidor de distribución | No mitiga | **No mitiga** (reescribe ambos) | Mitiga |
| Compromiso del build pipeline del publisher | No mitiga | No mitiga | **No mitiga** (ambos auténticos pero maliciosos) |
| Compromiso de la clave privada del publisher | No mitiga | No mitiga | **No mitiga** |
| Corrupción en tránsito (bit-flip) | Mitiga (MAC TLS) | Mitiga | Mitiga |

Lecciones:

- Las defensas se *acumulan*. Nada sustituye a GPG, nada sustituye a TLS, nada sustituye al checksum.
- Hay ataques que **ninguna** de estas tres defensas mitiga: compromiso del build pipeline (ejemplos reales: SolarWinds, event-stream, xz-utils). Para eso hacen falta otras defensas (SBOM, reproducible builds, revisión humana).

---

## 8. `curl … | bash` revisitado

```bash
curl -sSL https://tool.example/install.sh | bash
```

Es la antítesis de todo lo anterior:

- Ejecuta código no auditado en tu máquina con tus permisos.
- No hay checksum, no hay firma, ni siquiera hay archivo intermedio para inspeccionar.
- El servidor puede servir contenido **distinto** al script `curl` sin TTY vs. `curl` con TTY (truco conocido: *detectar pipe y servir otra cosa*).
- Si la conexión se corta a mitad del script, bash ejecuta lo recibido y puede dejar el sistema en un estado inconsistente (`rm -rf` parcial, por ejemplo).

Mitigaciones razonables cuando no hay alternativa:

1. **Descargar primero, inspeccionar, ejecutar después:**
   ```bash
   curl -fsSL https://tool.example/install.sh -o install.sh
   less install.sh                            # auditoría humana
   sha256sum install.sh                       # compararlo con el publicado
   bash install.sh
   ```
2. **Preferir siempre el paquete oficial** (apt/dnf/brew) o un binario con firma GPG.
3. **Si el proyecto solo ofrece `curl | bash`**: eso te dice algo del proyecto. Decidir en consecuencia.

---

## 9. Logging y auditoría del fetch

Un pipeline de descarga en producción debería dejar rastro, no solo bytes:

- Qué URL se intentó, qué URL final (post-redirect).
- Qué tamaño se obtuvo, qué hash resultante.
- Qué checksum esperado contra qué checksum real.
- Qué fingerprint firmó, con qué timestamp.
- Qué exit code final y por qué.

Un log plano `stderr` prefijado con `[INFO] / [WARN] / [ERROR]` + timestamp cumple el 90% de los casos. Se verá en la actividad 2.

---

## 10. Reproducibilidad: la meta de fondo

Un fetch "reproducible" significa: dado el mismo input (URL + checksum esperado + clave de verificación), obtenés el mismo output *o un error claro*. Nunca "silencio y archivo distinto".

Esto es lo que permite:

- Builds auditables (Reproducible Builds).
- Rollbacks confiables.
- CI/CD determinista.
- Supply chain security (si cada capa es reproducible, el blast radius de un compromiso se acota).

---

## 11. Errores frecuentes

- **"Me falla la verificación de certificado, le pongo `--no-check-certificate` y sigo."** Mal. Lo que falla es tu almacén de CAs o el certificado del server. Arreglá *eso*.
- **"Comparo el hash a mano copiando desde la web."** Mal. Un atacante que puede reescribir el tarball probablemente puede reescribir la web. Usá `--check` contra un `SHA256SUMS` firmado.
- **"`gpg --verify` dijo `Good signature`, listo."** Insuficiente si no verificaste el fingerprint contra una fuente independiente. "Good signature from Mallory" es "good signature".
- **"Reintento infinito con `--tries=0`."** Un script que no falla nunca es un script que miente al orquestador.
- **"Uso `-O` y `-c` juntos sin pensar."** Si el `-O` apunta a un archivo preexistente con otro contenido, el resume genera un archivo corrupto que *parece* exitoso.

---

## 12. Preguntas de reflexión (responder sin consultar)

1. Un publisher sirve `tool.tar.gz` y `tool.tar.gz.sha256` desde el **mismo** CDN. ¿Qué ataque mitiga ese sidecar y cuál **no**? ¿Cómo cambiaría la respuesta si además publicara `tool.tar.gz.sha256.asc` firmado?
2. ¿Por qué `wget --tries=0` es una mala idea en producción? Da un escenario concreto donde cause daño operativo.
3. Un script usa `--no-check-certificate` "porque en staging el cert es self-signed". ¿Qué dos cambios harías para eliminar esa flag sin romper el deploy en staging?
4. ¿Qué garantiza `gpg --verify` cuando devuelve exit code `0` pero muestra "WARNING: This key is not certified"? ¿Es suficiente para un pipeline de CI?
5. En un pipeline de descarga, ¿en qué orden conviene ejecutar: `wget`, `sha256sum --check`, `gpg --verify`? Justificá cada paso: ¿qué ganás ejecutando `gpg --verify` *antes* del checksum? ¿Y después?
6. ¿Qué ataque real no mitiga **ninguna** de las defensas vistas en este módulo? ¿Qué defensas adicionales existen?
