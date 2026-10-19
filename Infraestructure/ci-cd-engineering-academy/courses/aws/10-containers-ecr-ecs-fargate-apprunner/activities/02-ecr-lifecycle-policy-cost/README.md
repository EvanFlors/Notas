# Actividad 02 — ECR lifecycle policy para contener coste

## 1. Identificacion

- **ID:** `aws-10-02-ecr-lifecycle-policy-cost`
- **Tecnologia:** `aws`
- **Modulo:** `aws-10-containers-ecr-ecs-fargate-apprunner`
- **Dificultad:** intermediate
- **Duracion estimada:** 50-70 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Un repositorio ECR crece sin control: cada *push* de CI anade una imagen (puede
pesar 300 MB-1 GB), muchas quedan huerfanas sin tag al re-taggear, y
nadie borra las antiguas. En 6 meses el bill de ECR puede pasar de "cero" a
cientos de dolares por repo, especialmente si hay replicacion cross-region.

Las **ECR lifecycle policies** son reglas declarativas que ECR evalua en
segundo plano y aplican `expire` sobre imagenes que cumplen un criterio
(antiguedad o cuenta maxima). Son **la** palanca para contener coste en ECR y
una decision de arquitectura: cuanto riesgo de "no poder rollback a hace 6
meses" aceptas a cambio de no pagar por basura.

Tu encargo: **disenar una lifecycle policy con al menos tres reglas**,
combinando criterios por tag y por cuenta/antiguedad, y defender cada regla
por escrito en `README-INTENT.md`.

**No hay cuenta AWS real.** El entregable es JSON + Markdown. El validador
comprueba estructura (no corre `aws ecr put-lifecycle-policy`).

## 3. Objetivos

Al terminar deberias poder, **sin consultar la leccion**:

- Escribir una lifecycle policy valida con la estructura oficial de ECR
  (`rules[].rulePriority`, `.selection.tagStatus`, `.selection.countType`,
  `.action.type`).
- Explicar por que las reglas se evaluan en orden ascendente de `rulePriority`
  y por que la mas "general" (la ultima red de seguridad) suele ir ultima.
- Justificar la diferencia entre `tagStatus: "tagged"` + `tagPrefixList`,
  `tagStatus: "untagged"` y `tagStatus: "any"`.
- Elegir entre `countType: "sinceImagePushed"` (antiguedad) y
  `countType: "imageCountMoreThan"` (volumen) con criterio.

## 4. Prerrequisitos

- Haber leido `../../theory/lesson.md` (seccion de ECR y lifecycle policies).
- Haber recorrido `../../examples/01-ecr-push-from-ci/`.
- Herramientas: `bash` y `jq`. Nada mas. **No** se necesita AWS CLI ni
  credenciales.
- Costos: **cero**.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/aws-10-ecr-lifecycle
cp -r starter/* /tmp/aws-10-ecr-lifecycle/
cd /tmp/aws-10-ecr-lifecycle
```

### 5.2 Escribe `lifecycle-policy.json`

Formato oficial de ECR (ver docs AWS "LifecyclePolicy JSON Syntax"):

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 10 release images tagged v*",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["v"],
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": { "type": "expire" }
    }
  ]
}
```

Requisitos minimos (los exige el validador):

- Clave raiz **`rules`** con un array de **al menos 3** reglas.
- Cada regla tiene `rulePriority` (entero), `description` (string no vacio),
  `selection` y `action`.
- `rulePriority` **unico** por regla, y las reglas **ordenadas ascendentemente**.
- `action.type` siempre `"expire"` (ECR solo soporta expire).
- Cada `selection` tiene `tagStatus` en `{"tagged","untagged","any"}` y un
  `countType` en `{"imageCountMoreThan","sinceImagePushed"}` con su
  `countNumber` (y `countUnit: "days"` si usas `sinceImagePushed`).
- Si `tagStatus == "tagged"` debes incluir `tagPrefixList` **o** `tagPatternList`
  (uno de los dos).
- Al menos una regla **retiene** release (tagged `v*` o similar) y al menos una
  **limpia untagged** y al menos una es una **red de seguridad** por antiguedad
  (`sinceImagePushed`).

### 5.3 Escribe `README-INTENT.md`

Debe contener:

- Una seccion titulada **`## Resumen`** (2-3 parrafos) explicando el objetivo y
  los *trade-offs* (coste vs capacidad de rollback).
- Una seccion por cada regla, en el formato:

  ```
  ## Regla N: <titulo corto>
  - Que hace:
  - Por que:
  - Riesgo que mitiga:
  - Riesgo que introduce:
  ```

- Una seccion **`## Orden de evaluacion`** justificando por que las reglas
  estan en ese orden (ECR las aplica por `rulePriority` ascendente; una regla
  mas general al final actua como *backstop*).
- Mencion explicita de **CloudWatch Metrics** o **ECR repository metrics**
  como fuente para medir si la policy esta actuando (contar imagenes borradas).

### 5.4 Entregables

Dos archivos en tu directorio de trabajo:

```
/tmp/aws-10-ecr-lifecycle/
├── lifecycle-policy.json
└── README-INTENT.md
```

### 5.5 Validar

```bash
bash tests/validate.sh /tmp/aws-10-ecr-lifecycle
```

## 6. Resultado esperado

- `lifecycle-policy.json` es JSON valido con 3+ reglas bien formadas.
- `README-INTENT.md` justifica cada regla y menciona orden de evaluacion.
- Validador imprime `OK: estructura valida` y sale con codigo 0.

## 7. Criterios de aceptacion

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada regla tiene *justificacion* escrita, no solo listada.
- **Reproducibilidad**: alguien podria aplicar tu JSON con
  `aws ecr put-lifecycle-policy --repository-name capstone-api --lifecycle-policy-text file://lifecycle-policy.json`
  y entender el intent del autor.

## 8. Validacion

```bash
bash tests/validate.sh /tmp/aws-10-ecr-lifecycle
```

Compara con `solution/REFERENCE.md` **despues** de intentar tu propia
version.

## 9. Preguntas de reflexion

1. Si todas tus imagenes se taggean con el commit SHA (`a1b2c3d`), ¿como se
   diferencia "release" de "ephemeral"? ¿Cambiarias la convencion de tags?
2. Si por error tu CI empieza a hacer *push* de 100 imagenes/hora untagged,
   ¿cuanta cuota tiene ECR? ¿La regla "limpia untagged" se dispara en tiempo
   real o periodicamente?
3. ¿Que pasa si una imagen esta *en uso* por un servicio ECS activo pero
   `rulePriority` la selecciona para expirar? (Pista: lee los docs de "image
   in use" en lifecycle policies.)
4. ¿Como combinas una lifecycle policy con **replicacion cross-region** sin
   que una region "se adelante" a la otra?

## 10. Extensiones

- Anade una cuarta regla que **retenga** por **tag suffix** (p. ej.
  `-rollback`) para marcar manualmente imagenes "no borrar jamas".
- Escribe una regla que use `tagPatternList` con comodines (`v1.*`) para
  limitarse a una serie major.
- Investiga la metrica `AWS/ECR` `RepositoryPullCount` y propone una alarma de
  CloudWatch "repo sin pulls en 90 dias -> candidato a borrado".

## 11. Limpieza

```bash
rm -rf /tmp/aws-10-ecr-lifecycle
```

Nada que destruir en AWS.
