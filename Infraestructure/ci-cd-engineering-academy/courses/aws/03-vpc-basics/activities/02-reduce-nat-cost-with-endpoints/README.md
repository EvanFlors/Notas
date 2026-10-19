# Actividad 02 — Reducir el costo de NAT con VPC endpoints

## 1. Identificación

- **ID:** `aws-03-02-reduce-nat-cost-with-endpoints`
- **Tecnología:** `aws`
- **Módulo:** `aws-03-vpc-basics`
- **Dificultad:** beginner
- **Duración estimada:** 50–70 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Un equipo te pasa esta factura mensual aproximada de **VPC / NAT Gateway** en 3 AZ:

- NAT Gateway (3 unidades, siempre on): ~**$97** en horas.
- **Procesamiento NAT**: ~**$54** este mes (1.2 TB a $0.045/GB).
- Total VPC: **~$151/mes**.

Pides el detalle del tráfico que pasa por NAT. Resulta ser:

| Destino                                         | Volumen/mes | Notas                                    |
|------------------------------------------------|-------------|------------------------------------------|
| S3 (mismo región)                               | 700 GB      | pipelines ETL leen/escriben objetos      |
| DynamoDB (mismo región)                         | 50 GB       | writes de telemetría                     |
| ECR (`docker pull` de imágenes en Fargate)      | 300 GB      | jobs batch, varias rebuilds al día       |
| Secrets Manager                                 | 1 GB        | la app lee secretos al arrancar          |
| CloudWatch Logs                                 | 100 GB      | logs de la app                           |
| APIs externas (Stripe, Twilio, OpenAI)          | 40 GB       | tráfico real a Internet                  |
| Actualizaciones apt/yum                         | 9 GB        | cuando se arrancan AMIs                  |

Tu encargo: **auditar el stack, proponer endpoints, calcular ahorro**.

**No se despliega nada.** El entregable es `COST-ANALYSIS.md`.

## 3. Objetivos

Al terminar deberías poder:

- Clasificar cada flujo como:
  - **Gateway endpoint** (S3, DynamoDB) → gratis siempre.
  - **Interface endpoint** → vale la pena si el volumen justifica.
  - **Dejar por NAT** → tráfico esporádico o verdaderamente a Internet.
- Calcular el ahorro mensual estimado.
- Dibujar el diagrama antes y después.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (secciones 3, 8, 9).
- Haber recorrido `examples/03-s3-gateway-endpoint/`.
- `bash` y un editor.

**Costos:** cero.

## 5. Instrucciones

### 5.1 Preparar el workspace

```bash
mkdir -p /tmp/aws-03-nat-endpoints
cd /tmp/aws-03-nat-endpoints
```

### 5.2 Escribe `COST-ANALYSIS.md`

Debe tener **cuatro secciones**:

#### Sección A — Clasificación por flujo

Tabla con al menos 7 filas (una por destino arriba):

```
| Destino | Volumen | Clasificación | Justificación |
|---------|---------|---------------|---------------|
| S3      | 700 GB  | Gateway endpoint | Gratis, siempre vale la pena |
| ...     | ...     | ...           | ...                           |
```

Valores de clasificación permitidos: `Gateway endpoint`, `Interface endpoint`, `Dejar por NAT`.

#### Sección B — Cálculo de ahorro

Muestra cuánto cuesta hoy cada flujo pasando por NAT (volumen × $0.045) y cuánto costaría después. Al menos:

- Cálculo del ahorro total mensual.
- Cálculo del coste añadido por los Interface endpoints que propongas (hora × AZ × 24 × 30 + GB × $0.01).
- Ahorro neto final.

Formula de referencia:

```
coste_NAT_actual = sum(volumen_GB × 0.045)      por flujo
coste_IE_mensual = n_servicios × 3_AZ × 0.01 × 24 × 30
                 + sum(volumen_GB × 0.01)        solo para flujos movidos a IE
ahorro_neto      = coste_NAT_actual - coste_despues
```

#### Sección C — Diagrama antes/después

ASCII. **Antes**: todas las flechas convergen a NAT -> IGW -> Internet. **Después**: separa claramente los flujos que van por Gateway endpoint, los que van por Interface endpoint y los que siguen por NAT.

#### Sección D — 5 recomendaciones numeradas

```
1. ...
2. ...
3. ...
4. ...
5. ...
```

Cada una debe ser accionable y justificada.

### 5.3 Validación

```bash
bash <ruta-repo>/courses/aws/03-vpc-basics/activities/02-reduce-nat-cost-with-endpoints/tests/validate.sh /tmp/aws-03-nat-endpoints
```

## 6. Resultado esperado

- `/tmp/aws-03-nat-endpoints/COST-ANALYSIS.md` existe.
- Tiene las 4 secciones.
- La tabla tiene al menos 7 filas.
- Hay un diagrama ASCII antes/después.
- Hay 5 recomendaciones numeradas.
- El validador sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: números coherentes; S3 y DynamoDB clasificados como Gateway endpoint; APIs externas y apt/yum como "Dejar por NAT".
- **Reproducibilidad**: alguien puede recorrer tu cálculo con una calculadora y llegar al mismo resultado ±5 %.

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-03-nat-endpoints
```

## 9. Preguntas de reflexión

1. ¿Por qué un Interface endpoint para CloudWatch Logs puede **no** ahorrar nada si el volumen es bajo?
2. ¿Qué pasa con el tráfico apt/yum a `*.ubuntu.com` si no hay ningún endpoint? ¿Vale la pena cachear en S3?
3. ¿Qué cambia si tu stack está en **una sola AZ** en vez de 3? ¿Por qué los Interface endpoints se vuelven más baratos relativamente?
4. ¿Qué ocurriría si tu bucket S3 estuviera en **otra región**? ¿Sigue sirviendo el Gateway endpoint?
5. ¿Por qué el ECR Interface endpoint casi siempre vale la pena en entornos con pipelines CI/CD agresivos?

## 10. Extensiones

- Añade una tabla con **break-even** por servicio: a partir de cuántos GB/mes el Interface endpoint se amortiza vs seguir pagando NAT.
- Propón una **estrategia de cache ECR** (pull-through cache) y estima su impacto adicional.
- Dibuja el diagrama de una **cuarta** opción: eliminar NAT Gateway completamente moviendo todo lo movible a endpoints y dejando las APIs externas en una subnet pública diferente para pocos jobs.

## 11. Limpieza

```bash
rm -rf /tmp/aws-03-nat-endpoints
```

No hay recursos AWS que destruir (no se desplegó nada).
