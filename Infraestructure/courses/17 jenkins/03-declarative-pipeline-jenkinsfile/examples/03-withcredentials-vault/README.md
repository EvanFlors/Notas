# Ejemplo 03 — `withCredentials` y `credentials('id')`

> Lectura y análisis. Compara los dos mecanismos de credential binding en Declarative Pipeline y fija los antipatrones críticos a evitar.

## 1. Qué muestra

- **`credentials('id')` en `environment { }`** para `secret_text` y `username/password`.
  - `secret_text` → una sola variable con el valor.
  - `username/password` → tres variables: `NAME`, `NAME_USR`, `NAME_PSW`.
- **`withCredentials { }` como bloque** para tipos no soportados por `credentials()`:
  - `string(...)` para secret_text con nombre explícito.
  - `file(...)` para credenciales de tipo archivo (kubeconfig, cert).
  - `usernamePassword(...)` con nombres de variables personalizados.
- **Varias credenciales inyectadas en un solo bloque** `withCredentials` para evitar bloques anidados.

## 2. Lectura clave

1. **Jenkins enmascara los valores en los logs** siempre que **coincidan exactamente**. Si transformas el secret (base64, substring), el enmascarado deja de funcionar. Nunca transformes secretos en Groovy.
2. **Nunca `echo "$SECRET"` ni `set -x`** en un `sh` que use secretos. Un `set -x` dentro de un script que reciba el secret en argv dejará el valor en los logs al echear la línea de ejecución.
3. **`credentials()` sólo cubre tipos simples**. Para SSH keys, certificados o archivos, `withCredentials { file(...) }` es la única vía oficial.
4. **El `credentialsId` es un contrato**: debe existir en el *credentials store* del folder/global. Si se usa un id inexistente, el build falla en tiempo de inyección — no cuando el `sh` intenta usar la variable.

## 3. Antipatrones evidentes y por qué duelen

| Antipatrón | Por qué duele |
|------------|---------------|
| `def pass = env.REGISTRY_CREDS_PSW; sh "curl -u user:${pass} ..."` | Concatenación en Groovy → el enmascarado no cubre la línea generada en logs. |
| `withCredentials` anidados en 4 niveles | Difícil de leer y auditar. Un solo bloque con varias entradas resuelve igual. |
| Secreto en argumento (`sh "vault login ${env.VAULT_TOKEN}"`) | El argumento acaba en `ps` y, con `set -x`, en los logs. Pásalo por env var o stdin. |
| Reusar un `credentialsId` tipo "token-everything" para 5 servicios distintos | Rotación acoplada, blast-radius grande, auditoría imposible. |

## 4. Preguntas de autocomprobación

1. ¿Qué pasa si usas `credentials('ssh-deploy-key')` sobre una credencial tipo SSH key?
2. ¿Dónde está documentado que los nombres `NAME_USR` / `NAME_PSW` son los sufijos oficiales (y no `_USERNAME` / `_PASSWORD`)?
3. Si tienes un `withCredentials` con `file(credentialsId: 'kc', variable: 'KUBECONFIG')`, ¿sigue existiendo el archivo tras salir del bloque?
4. ¿Por qué `vault status` lee `VAULT_TOKEN` del env en vez de recibirlo por argumento, y qué ventaja operativa tiene?
