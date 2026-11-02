# Ejemplo 01 — `wget` con resume y reintentos

## Concepto que demuestra

Cómo se combinan `-c`, `--tries`, `--timeout`, `--waitretry` y `--retry-connrefused` para obtener una descarga que sobrevive a red flaky y falla *claro* cuando no puede completarse.

## Contexto

Un script de deploy baja un artefacto de 200 MB desde un mirror con conexiones intermitentes. Queremos que: reanude si se corta, reintente ante fallas transitorias, se rinda tras N intentos, y nunca ignore errores de TLS.

## Objetivo

Al terminar, podrás responder:

- ¿Qué pasa si corto la red a mitad de descarga y la restablezco?
- ¿Qué pasa si el servidor devuelve `404`?
- ¿Por qué el script falla con exit code no-cero y qué código elegimos?

## Prerrequisitos

- `wget` instalado (`wget --version` ≥ 1.20).
- Bash.
- Conectividad a Internet (el demo usa un recurso público).

## Ejecución

Leé el script `files/demo.sh` antes de ejecutarlo:

```bash
bash files/demo.sh
echo "exit code: $?"
```

Después, probá tres variantes manualmente:

```bash
# 1. URL que no existe → debe fallar rápido con exit no-cero
URL="https://ftp.gnu.org/gnu/hello/hello-NO-EXISTE.tar.gz" bash files/demo.sh
echo "exit code: $?"

# 2. Resume: cortá la descarga con Ctrl+C a mitad y relanzá; con -c debería retomar
bash files/demo.sh                 # Ctrl+C a los 2 segundos
bash files/demo.sh                 # relanzar; mira "has been resumed"

# 3. Timeout bajo contra un host inalcanzable
URL="https://10.255.255.1/x.tar" bash files/demo.sh
# El timeout dispara, se reintentan los tries configurados, exit no-cero
```

## Resultado esperado

- Descarga exitosa deja el archivo en `/tmp/sys20-demo/hello-2.12.tar.gz`.
- Falla por 404 → exit code `69` con mensaje `ERROR: fetch de ... falló`.
- Falla por timeout → exit code `69` tras agotar `--tries`.
- Nunca aparece `--no-check-certificate` en la salida.

## Interpretación

- `-c` evita bajar lo que ya está en disco; combinado con `--tries` y `--waitretry`, convierte un error transitorio en un reintento.
- `--retry-connrefused` cambia el comportamiento default (que *no* reintenta ante `ECONNREFUSED`) — útil cuando el servidor está arrancando.
- Exit code `69` (`EX_UNAVAILABLE`) comunica al orquestador que *el servicio* no respondió; es distinto de `2` (uso incorrecto) o `1` (error genérico).

## Errores frecuentes

- Olvidar `--read-timeout`: el script se cuelga indefinidamente ante un peer que acepta conexión y no envía bytes.
- Usar `--tries=0`: nunca falla, nunca libera al orquestador.
- Agregar `--no-check-certificate` "temporalmente": el "temporalmente" se queda.

## Limpieza

```bash
rm -rf /tmp/sys20-demo
```
