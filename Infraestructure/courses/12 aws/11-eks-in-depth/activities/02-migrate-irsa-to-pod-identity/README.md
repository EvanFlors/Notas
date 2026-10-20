# Actividad 02 — Migrar un workload de IRSA a EKS Pod Identity

## 1. Identificación

- **ID:** `aws-11-02-migrate-irsa-to-pod-identity`
- **Tecnología:** `aws`
- **Módulo:** `aws-11-eks-in-depth`
- **Dificultad:** advanced
- **Duración estimada:** 75–100 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Tu organización lleva 18 meses usando **IRSA** en producción. Funciona, pero:

- Cada cluster nuevo pide re-crear roles IAM (OIDC provider distinto).
- Las trust policies verbosas son un foco frecuente de typos.
- Un equipo quiere **reusar el mismo rol en 3 clusters** para una app común.

Alguien del equipo propone migrar a **EKS Pod Identity**. Tu trabajo: diseñar la migración, escribir los manifiestos antes/después y argumentar la decisión.

### Nota de coste

**$0.** Esta actividad es puramente de diseño y escritura. No se levanta ningún cluster. Si tienes IRSA en un cluster real y quieres practicar la migración allí, el coste del cluster corre por tu cuenta.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Nombrar al menos **4 diferencias técnicas** entre IRSA y Pod Identity (setup, trust, token, reuso, SDK).
- Escribir el **ServiceAccount + trust policy IAM** para IRSA **y** para Pod Identity con la misma política mínima (p. ej. `s3:GetObject` sobre un bucket).
- Diseñar un **plan de migración por fases**: dual-run, cutover, rollback.
- Decidir IRSA vs Pod Identity para 3 escenarios distintos.
- Explicar por qué Pod Identity **no** reemplaza patterns externos a EKS (ECS task roles, EC2 instance profiles).

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §6, §7).
- Haber recorrido `../../examples/02-irsa-s3-access-from-pod/`.
- Herramientas: `bash` y un editor Markdown/YAML. Nada más.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/aws-11-02/{manifests,docs}
cd /tmp/aws-11-02
```

### 5.2 Workload base

El workload de ejemplo es trivial: un `Deployment` que necesita leer y escribir objetos en `s3://my-demo-bucket/*`. Account id ficticio **siempre** `123456789012`. Nombre del rol IAM: `app-s3-rw`.

### 5.3 Escribir `manifests/sa-irsa.yaml` (ANTES)

Debe incluir:

1. El `ServiceAccount` con la **anotación IRSA** (`eks.amazonaws.com/role-arn`).
2. Un bloque de comentario con la **trust policy IAM** correspondiente: `AssumeRoleWithWebIdentity`, con `Federated: arn:aws:iam::123456789012:oidc-provider/...` y condiciones `sub` y `aud` precisas.
3. Un bloque de comentario con la **política IAM mínima** del rol: `s3:GetObject`, `s3:PutObject` sobre `arn:aws:s3:::my-demo-bucket/*`.
4. El `Deployment` referenciando el `ServiceAccount`.

### 5.4 Escribir `manifests/sa-pod-identity.yaml` (DESPUÉS)

Debe incluir:

1. El `ServiceAccount` **sin** anotación IRSA (ya no hace falta).
2. Un bloque de comentario con la **trust policy IAM** simplificada: `Principal: Service: pods.eks.amazonaws.com`, acción `sts:AssumeRole` + `sts:TagSession`.
3. Un bloque de comentario con la **misma política IAM mínima** del rol.
4. Un bloque de comentario con la **Pod Identity Association** vía CLI o Terraform:
   ```
   aws eks create-pod-identity-association \
     --cluster-name eks-demo \
     --role-arn arn:aws:iam::123456789012:role/app-s3-rw \
     --namespace default \
     --service-account app
   ```
5. El `Deployment` referenciando el `ServiceAccount` (idéntico al anterior — ese es el punto).

### 5.5 Escribir `docs/MIGRATION.md`

Secciones obligatorias:

```
## Comparación IRSA vs Pod Identity

| Dimensión | IRSA | Pod Identity |
|-----------|------|--------------|
| Setup por cluster | ... | ... |
| Trust policy | ... | ... |
| Token flow | ... | ... |
| Reuso cross-cluster | ... | ... |
| Compatibilidad fuera de EKS | ... | ... |
| Observabilidad (CloudTrail) | ... | ... |
| (al menos 4 filas más que estas) |

## Plan de migración por fases

### Fase 1 — Dual-run
- ...

### Fase 2 — Cutover
- ...

### Fase 3 — Rollback (si algo sale mal)
- ...

## Matriz de decisión por escenario

### Escenario A — Greenfield, 1 cluster nuevo
Decisión: ...
Justificación: ...

### Escenario B — Legacy, 20 workloads IRSA en producción
Decisión: ...
Justificación: ...

### Escenario C — Workload cross-platform (corre también en ECS)
Decisión: ...
Justificación: ...

## Límite claro: lo que Pod Identity NO resuelve
- ...
```

### 5.6 Checklist conceptual (dentro de `MIGRATION.md` o aparte)

Añade al final una lista numerada con **7 preguntas** que harías a un equipo antes de autorizarles la migración (p. ej. *"¿tu SDK soporta Pod Identity? ¿Qué versión?"*).

### 5.7 Entregables

En `/tmp/aws-11-02`:

```
manifests/sa-irsa.yaml
manifests/sa-pod-identity.yaml
docs/MIGRATION.md
```

## 6. Resultado esperado

- Los 3 archivos existen.
- `MIGRATION.md` tiene las 4 secciones (comparación, plan, matriz, límite).
- Los manifiestos tienen `ServiceAccount` + `Deployment` cada uno.
- `sa-irsa.yaml` menciona `eks.amazonaws.com/role-arn` y `AssumeRoleWithWebIdentity`.
- `sa-pod-identity.yaml` menciona `pods.eks.amazonaws.com` y `create-pod-identity-association`.
- `bash tests/validate.sh /tmp/aws-11-02` pasa.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: la comparación tiene al menos **6 filas**, cada una con contenido real (no "N/A").
- **Reproducibilidad**: un peer puede ejecutar el plan de migración leyéndolo.
- **Mantenibilidad**: YAML válido, Markdown bien formado, cero account ids reales.

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-11-02
```

El validador comprueba estructura y presencia de los markers clave. Compara `MIGRATION.md` con `solution/REFERENCE.md` para autoevaluarte semánticamente.

## 9. Preguntas de reflexión

1. ¿Por qué Pod Identity simplifica el *trust* pero no la *política* del rol?
2. ¿Qué pasa durante Fase 1 (dual-run) si un pod reinicia y el SDK elige la cadena de credenciales equivocada?
3. En el Escenario C, ¿qué patrón alternativo (sin IRSA, sin Pod Identity) usarías para un workload que corre también en ECS?
4. Si tu SDK AWS es muy viejo y **no** soporta Pod Identity, ¿cuál es tu única salida sin re-instrumentar la app?
5. ¿Por qué `sts:TagSession` entra en la trust policy de Pod Identity y no entraba en IRSA?

## 10. Extensiones

- Añade una **sección de observabilidad**: qué CloudTrail events verás con IRSA vs Pod Identity y cómo detectar una llamada fallida.
- Añade un **Terraform snippet** que cree la Pod Identity Association (`aws_eks_pod_identity_association`) junto con el rol IAM.
- Añade un **4.º escenario** propio.

## 11. Limpieza

```bash
rm -rf /tmp/aws-11-02
```

No hay recursos AWS que limpiar porque **no se creó nada en AWS**.
