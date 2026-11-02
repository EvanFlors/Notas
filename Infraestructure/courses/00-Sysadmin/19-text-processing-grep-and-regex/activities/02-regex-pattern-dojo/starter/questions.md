# Patrones a escribir

Para cada clase, rellena en `patterns.sh`:

- `REGEX_<CLASE>` — la regex, **anclada** con `^...$`.
- `ENGINE_<CLASE>` — `E` para `grep -E` (ERE) o `P` para `grep -P` (PCRE).

## 1. IPV4

- Cuatro octetos 0–255 separados por `.`.
- Rechaza octetos vacíos, > 255, con signo, con ceros a la izquierda **sí** permitidos (`010.000.000.001` es ambiguo; nuestro dataset no lo exige, pero decídelo tú y documéntalo si quieres rechazarlos).
- Engine: `E`.

## 2. EMAIL (pragmático)

- Forma: `local@dominio.tld`.
- `local`: alfanumérico más `._%+-`, al menos 1 carácter.
- `dominio`: al menos un label + un punto + TLD de 2+ letras.
- No pretendes RFC 5322. Lo que tu regex no detecte en la práctica, lo detecta el envío real del correo.
- Engine: `E`.

## 3. ISODATE

- `YYYY-MM-DD` donde `YYYY` ∈ `1900..2099`, `MM` ∈ `01..12`, `DD` ∈ `01..31`.
- Léxica, no semántica (no te preocupes por febrero 30).
- Engine: `E`.

## 4. UUID

- 8-4-4-4-12 hex, con guiones, canónica.
- Admite mayúsculas y minúsculas.
- (Opcional) acota la **versión** al nibble `[1-5]` del tercer grupo. El dataset incluye un negativo con versión 6.
- Engine: `E`.

## 5. BASHVAR

- `[A-Za-z_][A-Za-z0-9_]*`.
- No vacío.
- Engine: `E`.

## 6. URL

- `http://` o `https://` + host (dominio o `localhost`) + puerto opcional + path opcional + query opcional.
- Rechaza `ftp://`, URLs sin esquema, con espacios internos.
- Engine: `E`.

## 7. HEXCOLOR

- `#` + exactamente 3 o 6 hex, case-insensitive.
- Para el case-insensitive aquí usamos PCRE con `(?i)` (sin recurrir a `[A-Fa-f]`, aunque también valdría en ERE).
- Engine: `P`.
