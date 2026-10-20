# CMEK sobre GCS — impacto de la rotación (solución de referencia)

Este documento acompaña a `main.tf`, `iam-binding-gcs-service-agent.json` y `envelope-demo.py`. Explica el porqué de cada decisión y qué pasa (y qué no) al rotar la **CMEK**.

## Decisiones de diseño

- **`rotation_period = "7776000s"` (90 días)**. Es el default sensato: suficiente para cumplir frameworks típicos y evita acumulación excesiva de versiones activas. Bajar a 30 días triplica el número de versiones vivas al año (y por tanto el coste de key-version-months); subir por encima de 365 días suele chocar con guidelines de seguridad.
- **`protection_level = "SOFTWARE"`**. HSM es ~10x más caro y solo se justifica con FIPS 140-2 Level 3 explícito. Para la mayoría de workloads, software es correcto.
- **`lifecycle { prevent_destroy = true }`** en la **CryptoKey**. Destruir una CryptoKey mientras hay objetos cifrados con ella equivale a destruir esos objetos. Esta barrera impide que un `terraform destroy` accidental cause pérdida de datos irreversible.
- **`depends_on` del bucket sobre el IAM binding**. Garantiza que el *service agent* ya tiene permiso antes de que GCS intente usar la clave. Sin esta dependencia explícita, la primera `apply` falla el 50% de las veces por *race* en el plan.
- **Variables ficticias** (`demo-cmek-example`, `000000000000`): el plan es demostrativo y no se aplica. Nunca commitear project IDs ni project numbers reales.

## Impacto de la rotación

Rotar la CryptoKey **crea una nueva *primary version***. Lo que ocurre:

- **Objetos nuevos** se cifran con la nueva versión primary (envoltura DEK ↔ versión *N+1*).
- **Objetos antiguos** siguen apuntando a la versión con la que se cifraron. Cloud KMS mantiene esas versiones en estado `ENABLED` para *decrypt*; solo deja de usarlas para *encrypt*.
- **El bucket NO se re-cifra automáticamente.** La rotación es sobre la **KEK**, no sobre la DEK ni sobre el ciphertext. Es exactamente lo que demuestra `envelope-demo.py`: dos envueltas de la misma DEK con distintas KEK dan el mismo plaintext final; el ciphertext queda igual.

Si se necesita re-cifrar realmente (p. ej. porque se detectó compromiso de una versión y hay que invalidarla):

```bash
# Reescribir un objeto concreto fuerza re-encrypt con la primary actual.
gsutil rewrite -k gs://demo-cmek-example-data/path/to/object

# Para todo el bucket, en masa, iterando con -I y -m.
gsutil ls -r gs://demo-cmek-example-data/** | gsutil -m rewrite -k -I
```

Después se puede marcar la versión comprometida como `DISABLED` y, pasada la ventana, `DESTROY_SCHEDULED`. Entre que se marca `DESTROY_SCHEDULED` y se destruye realmente hay **30 días de gracia** (irreversible pasada esa ventana).

## Service agent

El *service agent* de GCS para un project tiene la forma:

```
service-<PROJECT_NUMBER>@gs-project-accounts.iam.gserviceaccount.com
```

Es la identidad que GCS **asume** cuando necesita cifrar/descifrar objetos del project. No existe físicamente hasta que la API de GCS se ha habilitado al menos una vez.

Para que un bucket con CMEK funcione, este principal necesita `roles/cloudkms.cryptoKeyEncrypterDecrypter` **sobre la CryptoKey concreta** (no sobre el project). Si falta:

```
Error: googleapi: Error 400: The Cloud KMS key cannot be used to encrypt this
bucket because the service account service-<PROJECT_NUMBER>@gs-project-accounts
.iam.gserviceaccount.com does not have the required permissions.
```

Es la causa #1 de tickets abiertos la primera vez que se despliega CMEK. El fix es siempre: añadir el binding, aplicar de nuevo.

## Costos

Este plan **no se aplica**: coste real = 0 USD.

Si se aplicara en un project real:

- Cloud KMS: ~0,06 USD por *key version* activa al mes. Con rotación 90d al cabo de un año hay ~5 versiones vivas → ~0,30 USD/mes.
- Operaciones de cifrado/descifrado: 0,03 USD por 10.000 operaciones. En un bucket con uso de prueba, despreciable (< 0,10 USD/mes).
- GCS en sí: tarifa estándar, independiente de CMEK.

Total estimado para esta configuración en pruebas: **menos de 1 USD/mes**. Si se añade HSM: ×10. Si se añade EKM: ×50 aproximadamente.

> Términos usados en este documento y en el demo: **CMEK** = clave gestionada por el cliente; **KEK** = key encryption key (CryptoKey en KMS); **DEK** = data encryption key (clave simétrica efímera por chunk); **envelope** = patrón de envoltura de la DEK por la KEK.
