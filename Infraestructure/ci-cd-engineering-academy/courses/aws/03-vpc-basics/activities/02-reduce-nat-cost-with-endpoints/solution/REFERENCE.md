# REFERENCE — aws-03-02-reduce-nat-cost-with-endpoints

> Una referencia razonada. No es la única respuesta correcta — los precios cambian y hay múltiples caminos óptimos.

## Sección A — Clasificación (modelo)

| Destino                         | Volumen | Clasificación      | Justificación |
|---------------------------------|---------|--------------------|---------------|
| S3 (misma región)               | 700 GB  | Gateway endpoint   | Gratis; es el único "no-brainer" absoluto. |
| DynamoDB (misma región)         | 50 GB   | Gateway endpoint   | Gratis; se añade con 1 línea más de HCL. |
| ECR (`docker pull`)             | 300 GB  | Interface endpoint | Volumen alto, constante y crítico; Interface endpoint se amortiza fácilmente. |
| Secrets Manager                 | 1 GB    | Interface endpoint | Volumen bajo pero necesario desde subnets privadas; coste de hora bajo (~$22/mes en 3 AZ) frente a eliminar un camino por NAT. Discutible: también se puede dejar por NAT si es solo arranque. |
| CloudWatch Logs                 | 100 GB  | Interface endpoint | A este volumen vale la pena; en volúmenes bajos (<10 GB) no. |
| APIs externas (Stripe, Twilio, OpenAI) | 40 GB | Dejar por NAT | Son servicios de Internet reales; no hay endpoint. |
| Actualizaciones apt/yum         | 9 GB    | Dejar por NAT      | Esporádico (al bootstrap), no justifica infraestructura extra. |

## Sección B — Cálculo (modelo)

### Antes

```
NAT horas (3 AZ):      3 × 0.045 × 24 × 30 = $97.2
NAT procesamiento:     (700+50+300+1+100+40+9) GB × 0.045 = 1200 × 0.045 = $54
Total NAT actual:      ~ $151.2 / mes
```

### Después

Interface endpoints: 3 servicios (ECR, Secrets Manager, CW Logs). Nota: ECR requiere `ecr.api` + `ecr.dkr` + S3 (ya cubierto por Gateway). Para simplificar modelamos **4** endpoints Interface por AZ.

```
Interface endpoints horas:   4 servicios × 3 AZ × 0.01 × 24 × 30 = $86.4
Interface endpoints GB:      (300 + 1 + 100) GB × 0.01 = $4.01
Gateway endpoints:           $0 (S3 + DynamoDB)
NAT que sigue:               (40 + 9) GB × 0.045 = $2.21
NAT horas (se mantienen):    $97.2   (no eliminamos NAT: APIs externas y apt siguen)
Total después:               $97.2 + $86.4 + $4.01 + $2.21 = ~ $189.8 / mes
```

Vaya: **"con todos los Interface endpoints salimos peor"**. ¡Ese es el punto didáctico! Elegir mal los Interface endpoints puede empeorar la factura.

Analicemos **más selectivamente**:

- Gateway endpoints (S3 + DynamoDB) → **ahorro directo**: 750 GB × 0.045 = **$33.75** gratis.
- Interface endpoint solo para ECR (el de más volumen):
  - Coste IE: 3 × 0.01 × 24 × 30 = $21.6
  - IE GB: 300 × 0.01 = $3.0
  - Ahorro frente a NAT: 300 × 0.045 = $13.5
  - Resultado: **IE le cuesta más** por hora (+$21.6) de lo que ahorra en procesamiento (+$10.5). Pierde $11/mes.

> **Conclusión numérica honesta:** en 3 AZ y a estos volúmenes, el **único cambio que paga** es activar los Gateway endpoints de S3 y DynamoDB.
>
> - Ahorro neto confiable: **~$33.75/mes**.
> - Interface endpoints: no justificados por volumen; se vuelven rentables cuando los GB mensuales superan ~2000 GB por servicio o cuando operas en 1-2 AZ.

### Factura después (recomendación mínima)

```
NAT horas:          $97.2  (sin cambios)
NAT procesamiento:  450 GB × 0.045 = $20.25   (quitamos S3+DynamoDB)
Gateway endpoints:  $0
Total despues:      ~ $117.45 / mes
Ahorro neto:        $151.2 - $117.45 = ~ $33.75 / mes
```

## Sección C — Diagrama (modelo)

### Antes

```
   App (subnet privada)
      |
      +--> rt-private (0.0.0.0/0 -> NAT) --> NAT GW --> IGW --> Internet
                                                                  |
                                                                  +--> S3
                                                                  +--> DynamoDB
                                                                  +--> ECR
                                                                  +--> Secrets Mgr
                                                                  +--> CW Logs
                                                                  +--> Stripe, Twilio, OpenAI
                                                                  +--> apt, yum repos
```

### Después (recomendación mínima)

```
   App (subnet privada)
      |
      +--> rt-private
             |-- pl-S3        --> vpce-s3 (Gateway, gratis) ---> S3
             |-- pl-DynamoDB  --> vpce-ddb (Gateway, gratis) --> DynamoDB
             '-- 0.0.0.0/0    --> NAT GW --> IGW --> Internet
                                                       |
                                                       +--> ECR / Secrets Mgr / CW Logs
                                                       +--> Stripe, Twilio, OpenAI
                                                       +--> apt, yum repos
```

(Interface endpoints opcionales si el volumen crece.)

## Sección D — 5 recomendaciones (modelo)

1. **Añade YA el Gateway endpoint de S3** asociado a las 3 RT privadas. Ahorro: ~$31.5/mes, coste $0, sin riesgo.
2. **Añade el Gateway endpoint de DynamoDB** mismo mecanismo. Ahorro: ~$2.25/mes, trivial.
3. **NO añadas Interface endpoints por reflejo**. Calcula el break-even: a $21.6/mes por servicio por 3 AZ, necesitas ~480 GB/mes/servicio para amortizar.
4. **Reevalúa cuando ECR cruce ~500 GB/mes**: en ese momento el Interface endpoint para `ecr.api` + `ecr.dkr` empieza a pagar.
5. **Considera consolidar a 2 AZ en entornos dev** (menos NAT, menos Interface endpoints por AZ). Reduce la factura ~33 % sin perder resiliencia útil.

## Puntos frecuentes de error en el análisis

- Clasificar S3 como "Interface endpoint" (es Gateway).
- Olvidar que un Interface endpoint cobra **por AZ**: multiplicar siempre por el nº de AZ.
- Suponer que los Interface endpoints eliminan el NAT: el NAT sigue mientras exista **cualquier** tráfico a Internet real.
- Añadir Interface endpoint para CloudWatch Logs con volumen bajo: lo encarece.
