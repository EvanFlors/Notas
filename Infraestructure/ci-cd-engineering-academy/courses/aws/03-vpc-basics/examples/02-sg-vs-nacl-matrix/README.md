# Ejemplo 02 — Matriz de decisión Security Group vs NACL

> Lectura. 6 escenarios. Para cada uno: la respuesta esperada y por qué.

## 1. Resumen de propiedades (recordatorio)

| Propiedad          | Security Group       | NACL                   |
|--------------------|----------------------|------------------------|
| Nivel              | ENI                  | Subnet                 |
| State              | Stateful             | Stateless              |
| Reglas             | Allow                | Allow + Deny           |
| Evaluación         | Unión                | Orden por `rule_number`|
| Referencias por ID | Sí (otro SG)         | No (solo CIDRs)        |

## 2. Los 6 escenarios

### Escenario A — "Quiero que `sg-app` solo acepte conexiones de `sg-alb`"

**Decisión:** Security Group.

**Por qué:** solo SGs pueden referenciar otro SG por ID. En NACL tendrías que listar los CIDR de las subnets del ALB (frágil, se rompe al escalar).

Regla:
```
sg-app: in 8080/tcp from sg-alb
```

### Escenario B — "Quiero bloquear un rango IP malicioso 203.0.113.0/24 en toda la subnet"

**Decisión:** NACL.

**Por qué:** SG es allow-only, no puede *denegar*. NACL permite:
```
rule 100  deny  from 203.0.113.0/24  all  (in)
rule 110  deny  from 203.0.113.0/24  all  (out)
rule 200  allow from 0.0.0.0/0       all  (in)
rule 210  allow from 0.0.0.0/0       all  (out)
```

### Escenario C — "Quiero que mi DB solo acepte en 5432 desde mis apps"

**Decisión:** Security Group.

```
sg-db: in 5432/tcp from sg-app
sg-db: out (vacío)
```

**Trampa común:** aunque el SG outbound esté vacío, las respuestas a conexiones entrantes salen porque el SG es **stateful**.

### Escenario D — "La subnet de datos nunca debe recibir tráfico SSH, pase lo que pase"

**Decisión:** NACL (como boundary) + buenos SGs.

**Por qué:** aunque un desarrollador abra accidentalmente `0.0.0.0/0:22` en un SG mal escrito, la NACL frena el paquete antes:
```
rule 90   deny  from 0.0.0.0/0  tcp 22  (in)
rule 100  allow from 0.0.0.0/0  all     (in)
```
Es defensa en profundidad. No reemplaza SGs mínimos; añade un boundary difícil de burlar accidentalmente.

### Escenario E — "Mi SG permite 443 inbound. ¿Necesito abrir el outbound para la respuesta?"

**Decisión:** NO.

**Por qué:** SG es stateful. La respuesta al handshake entrante usa la *conntrack* y sale sin regla.

Si en vez de SG fuera NACL, **sí** harías falta abrir el puerto efímero outbound (`1024-65535` para ser portable).

### Escenario F — "Quiero cambiar el SG asociado a una instancia sin reiniciarla"

**Decisión:** Se puede. Los SGs se modifican y los cambios son inmediatos sobre la ENI.

**Comparación:** cambiar la NACL de una subnet también es inmediato, pero afecta a **todas** las ENIs de esa subnet. Más impacto, menos quirúrgico.

## 3. Checklist rápido

```
¿Necesito denegar algo?                             -> NACL
¿Necesito referenciar otro grupo por identidad?     -> SG
¿Necesito aplicar la regla a 1 instancia concreta?  -> SG
¿Necesito un boundary de subnet (compliance)?       -> NACL
¿Quiero HA/menos reglas que mantener?               -> SG (unión), evita NACLs
```

## 4. Pregunta de autoevaluación

Un equipo propone usar NACLs en lugar de SGs "porque son más seguros, soportan deny". ¿Qué les respondes?

> Que la seguridad no se mide por "tener deny" sino por *mínimo privilegio bien expresado*. Los SGs lo expresan mejor en microsegmentación (referenciando IDs). La NACL es un boundary adicional, no un sustituto. Operacionalmente, mantener NACLs completas se vuelve inmanejable y es fuente de outages (olvidar el puerto efímero de retorno).
