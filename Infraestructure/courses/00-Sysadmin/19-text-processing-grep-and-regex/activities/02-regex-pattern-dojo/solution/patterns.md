# Solución — Dojo de patrones regex

Una regex idiomática por clase. **No son las únicas correctas**: cualquier
patrón que acepte 100 % de positivos y rechace 100 % de negativos del dataset
es válida.

```bash
# 1) IPV4 (ERE)
REGEX_IPV4='^((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])$'
ENGINE_IPV4='E'

# 2) EMAIL (ERE, pragmatico)
REGEX_EMAIL='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
ENGINE_EMAIL='E'

# 3) ISODATE 1900-2099 (ERE)
REGEX_ISODATE='^(19|20)[0-9]{2}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$'
ENGINE_ISODATE='E'

# 4) UUID v1-v5 (ERE)
REGEX_UUID='^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[1-5][0-9A-Fa-f]{3}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$'
ENGINE_UUID='E'

# 5) BASHVAR (ERE)
REGEX_BASHVAR='^[A-Za-z_][A-Za-z0-9_]*$'
ENGINE_BASHVAR='E'

# 6) URL (ERE, pragmatico)
REGEX_URL='^https?://[A-Za-z0-9.-]+(:[0-9]+)?(/[^ ?]*)?(\?[^ ]*)?$'
ENGINE_URL='E'

# 7) HEXCOLOR (PCRE, (?i) para case-insensitive)
REGEX_HEXCOLOR='^(?i)#([0-9a-f]{3}|[0-9a-f]{6})$'
ENGINE_HEXCOLOR='P'
```

## Notas de diseño

- **IPV4**: la alternancia `25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9]`
  cubre 0–255 sin aceptar `256`. `[1-9]?[0-9]` admite 0–99 permitiendo opcionalmente un dígito líder 1–9. Si quisieras rechazar octetos con cero a la izquierda (`010`), reemplaza por `(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])` y asegura que un solo dígito nunca llevará cero prefijo.
- **EMAIL**: `[A-Za-z0-9._%+-]+` cubre los locales habituales. El TLD exige `{2,}` letras — rechaza `foo@bar.` y `foo@bar.1`.
- **ISODATE**: 1900–2099 permite muchas apps reales sin complicar la regex. Para pre-1900 o post-2099 probablemente ya quieres una librería de fechas, no regex.
- **UUID**: `[1-5]` en la posición del "version nibble" rechaza v0 y v6+ (uno de los negativos del dataset es un UUID con v6).
- **BASHVAR**: idéntica a la que usa el propio bash para parsear nombres de variable.
- **URL**: deja fuera deliberadamente `ftp://`, mailto, etc. Para esos casos considera `uri` en Python o un parser real.
- **HEXCOLOR**: `(?i)` evita duplicar clases `[0-9a-fA-F]`. Es la razón de usar PCRE aquí (ERE no soporta flags inline).

## Trampas comunes

- Olvidar los **anclajes** `^...$`: tu regex matchea *dentro* de líneas, no la línea completa. El validador exige la línea completa.
- En IPv4, usar `\d{1,3}` sin acotar permite `999`.
- En EMAIL, poner `.*` en el local part consume demasiado.
- En URL, olvidar que el host puede tener puntos — `[A-Za-z0-9]+` no basta.
