# Reference solution — cap-07-01

Los tres modulos TF bajo `solution/terraform/<cloud>/` son la version resuelta
del starter. Puntos clave que diferencian la solucion de un starter mal
completado:

- `image` referenciado por `var.image_digest` (contiene `@sha256:`), nunca por
  tag.
- Identidad del runtime SEPARADA de la identidad que pullea la imagen /
  resuelve secretos:
  - AWS: `aws_iam_role.task` (distinto de `aws_iam_role.execution`).
  - GCP: `google_service_account.runtime` (distinto del SA por defecto de
    Compute).
  - Azure: `azurerm_user_assigned_identity.runtime` (distinto del principal
    que ejecuta Terraform).
- Secreto en el secret manager + binding de lectura a la identidad del runtime.
- Inyeccion de `APP_DB_DSN` al contenedor **por referencia** al secreto, nunca
  por `env.value` en claro.
- Postgres privado (sin IP publica).
- Tags/labels `capstone=07` para que el script de cleanup pueda detectar
  residuales.
