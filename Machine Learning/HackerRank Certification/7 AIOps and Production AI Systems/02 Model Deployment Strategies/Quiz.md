# Quiz: Model Deployment Strategies

**Escenario base:** Tu equipo prepara el deployment de un nuevo modelo de computer vision para inspección de calidad en una línea de manufactura. El modelo procesa imágenes y clasifica productos como *pass/fail*. El sistema maneja 500 imágenes por minuto durante horas pico. Un **falso negativo** (aceptar un producto defectuoso) cuesta **$100**. Un **falso positivo** (rechazar un producto bueno) cuesta **$10**. El **downtime del sistema** cuesta **$1,000 por minuto**.

---

### Pregunta 1

Tu modelo actual v1 corre en producción. El modelo v2 muestra 2% mejor accuracy en pruebas offline. ¿Qué patrón de deployment es el más apropiado para este escenario de manufactura de alto riesgo?

- Batch prediction corriendo v2 de noche para pre-computar todos los resultados.
- Blue-green deployment inmediato cambiando todo el tráfico a v2.
- Streaming deployment procesando imágenes a través de message queues.
- **Shadow deployment de v2 junto a v1 para validación antes de promoverlo.**

**Explicación:** El shadow deployment valida v2 con datos reales de producción **sin afectar las decisiones productivas**. Cada imagen se envía a ambos modelos; v1 responde al PLC de la línea y v2 solo logea predicciones para análisis offline. Dado el costo por error ($100 por falso negativo acumulado sobre 500 imgs/min = hasta $50k/hora de riesgo) y el costo de downtime ($1,000/min), la validación en producción sin impacto justifica el costo adicional de duplicar inferencia por unos días. Batch no sirve porque la decisión es en línea; blue-green a 100% sin validación en producción expone todo el flujo al riesgo de la mejora offline (2% accuracy en test ≠ 2% en producción por data drift o training-serving skew); streaming añade latencia innecesaria y no resuelve el problema de validación. Herramientas típicas: Istio `mirror` directive, Envoy request mirroring, pipelines Spark para análisis offline de los pares `(input, output_v1, output_v2)`.

---

### Pregunta 2

Estás construyendo una API de serving que será llamada por microservicios internos (todos escritos en Python y Go). El sistema debe manejar 10,000 requests por segundo con payloads grandes de imagen (2-5MB cada uno). ¿Cuál es la elección de protocolo más apropiada?

- **gRPC con Protocol Buffers por mejor performance con payloads grandes.**
- REST con JSON porque es universalmente compatible.
- GraphQL por capacidades flexibles de query.
- WebSockets para comunicación bidireccional.

**Explicación:** gRPC provee 2-5x mejor performance que REST+JSON gracias a la codificación binaria de Protocol Buffers (más compacta que JSON, menos CPU en serialización/deserialización) y a HTTP/2 (multiplexing de múltiples requests sobre una sola conexión TCP, header compression con HPACK). Para 10k rps con payloads de 2-5MB (= 20-50 GB/s agregados), cada ms de serialización y cada byte extra en el wire se multiplican dramáticamente. Como ambos lados son internos (Python y Go, ambos con soporte gRPC maduro: `grpcio` y `google.golang.org/grpc`), la pérdida de accesibilidad universal de REST no importa. REST+JSON sumaría overhead significativo; GraphQL está diseñado para APIs con queries flexibles del cliente (no para model serving); WebSockets no aporta sobre un flujo request/response. Herramientas industriales que usan gRPC a esta escala: Envoy (Lyft/Stripe), TensorFlow Serving, Triton Inference Server, servicios internos de Google/Meta.

---

### Pregunta 3

Tu modelo requiere 8GB de memoria GPU y usa 2 CPU cores durante inferencia. Las pruebas muestran que el modelo procesa 50 requests por segundo por GPU. Necesitas manejar 500 requests por segundo. ¿Cuántos Pods con GPU deberías solicitar en Kubernetes?

- 5 Pods con 1 GPU cada uno (exactamente 500 req/s de capacidad).
- 10 Pods para manejar el doble de la carga esperada.
- **7-8 Pods con 1 GPU cada uno (40-60% de over-provisioning por seguridad).**
- 1 Pod con 10 GPUs para mejor utilización de recursos.

**Explicación:** Dimensionar exactamente al peak (5 Pods para 500 rps) elimina todo margen: cualquier picoanomalía, falla de nodo, GC pause, o restart de pod (que tarda 30-60s en cargar el modelo) tira requests al 100% de utilización. Con 7-8 pods obtienes 350-400 rps como baseline sostenido y el HPA puede escalar hacia arriba para peaks reales, dando ~40-60% de headroom — el estándar en Google SRE para servicios user-facing. 10 pods duplica el costo sin ganancia proporcional. Un único pod con 10 GPUs es un SPOF catastrófico: una falla deja el servicio en cero y no permite rolling updates. La fórmula aplicable: `replicas = ceil(peak_rps × avg_latency / max_concurrent_per_pod × safety_factor)` con `safety_factor ∈ [1.3, 1.5]` típicamente. Complementar siempre con HPA (`autoscaling/v2`) usando métricas custom (queue depth, p99 latency) además de CPU.

---

### Pregunta 4

Durante un canary release con 10% de tráfico en v2, observas: v1 tiene 0.5% error rate, v2 tiene 1.2% error rate. Ambos han visto 10,000 requests. ¿Qué deberías hacer?

- Rollback inmediato de v2 porque la tasa de error es mayor.
- **Investigar los errores, verificar significancia estadística y decidir con base en la causa raíz.**
- Continuar el rollout porque 1.2% es aceptablemente bajo.
- Aumentar el tráfico de v2 a 50% para recolectar datos más rápido.

**Explicación:** Con solo 10,000 requests y una diferencia absoluta de 0.7% entre error rates, debes verificar significancia estadística antes de actuar. Aplicando el z-test para dos proporciones: `p_pool = (50+120)/20000 = 0.0085`, `SE = sqrt(0.0085 × 0.9915 × (2/10000)) ≈ 0.0013`, `z = 0.007/0.0013 ≈ 5.4`, que **sí** es estadísticamente significativo (|z| > 2.58 al 99%). Pero significancia estadística no implica significancia operacional ni root cause conocido: ¿son los mismos tipos de inputs los que fallan en ambos? ¿Es un bug en el nuevo serializer? ¿Es un edge case que v1 también maneja mal pero disfraza? Rollback automático sin investigar genera deuda operacional (no aprendes del incidente) y puede estar reaccionando a ruido en escenarios con menos muestras. Aumentar a 50% sin diagnosticar amplifica el blast radius exactamente cuando hay señales de problema. La respuesta correcta combina: pausar el rollout (congelar en 10%), analizar logs de errores de v2 que no fallaron en v1, verificar métricas por segmento (tipo de input, cliente, versión del tokenizador), y decidir con evidencia. Herramientas: Flagger pausa automáticamente ante anomalías; dashboards Grafana por versión; log aggregation (Loki/Elasticsearch) por `version` label.

---

### Pregunta 5

Tu imagen Docker para model serving pesa 8GB (el modelo es 5GB, la imagen base y las dependencias suman 3GB). Los pulls de la imagen tardan 5 minutos, ralentizando el autoscaling. ¿Cómo deberías optimizar?

- **Almacenar el modelo en S3 y descargarlo cuando los contenedores inician.**
- Usar una imagen base más pequeña como Alpine para reducir los 3GB de overhead.
- Comprimir el archivo del modelo para reducir su tamaño.
- Usar multi-stage builds para reducir las capas de la imagen.

**Explicación:** Descargar 5GB desde S3 en la misma región toma 30-60 segundos (bandwidth de ~100-500 MB/s dentro de AWS), mientras que el `docker pull` de 8GB sobre registry público tarda 5 minutos. Esto reduce el tiempo de scale-up ~10x y permite que el HPA responda a picos reales de tráfico. El patrón concreto es un `initContainer` en Kubernetes que ejecuta `aws s3 cp` a un `emptyDir` compartido antes de que arranque el contenedor principal; el modelo se monta read-only. La imagen base queda <1GB y se cachea en los nodos. Las otras opciones aportan poco: Alpine ahorra ~100-300MB pero el bulk (5GB del modelo) sigue ahí y además Alpine tiene problemas conocidos con wheels pre-compiladas de PyTorch/TensorFlow (usa musl en lugar de glibc). Comprimir el modelo gana 20-40% pero sigue inflando la imagen y añade tiempo de descompresión al startup. Multi-stage builds son excelente práctica, pero no resuelven que 5GB del modelo estén embebidos. Herramientas complementarias: `aws s3 cp --no-sign-request` con VPC endpoint para velocidad máxima, image registry caching con **Harbor** o **ECR pull-through cache**, y **registry mirror** regional para la imagen base.

---

### Pregunta 6

Tu API gateway usa un rate limit de sliding window de 1,000 requests por minuto por API key. Un cliente hace 900 requests en los primeros 30 segundos, luego 200 requests en los siguientes 30 segundos. ¿Qué debería suceder?

- Todos los 1,100 requests pasan porque promedian 18 requests por segundo.
- Todos los requests pasan porque cada ventana de 1 minuto está bajo 1,000.
- El gateway encola los requests en exceso para procesarlos más tarde.
- **Los primeros 1,000 requests pasan, los últimos 100 son rechazados con 429.**

**Explicación:** Sliding window rate limiting cuenta los requests en **cualquier ventana de 60 segundos**, no en ventanas fijas (eso sería tumbling window, estrategia distinta y más laxa). La implementación con Redis sorted sets `ZADD/ZCARD` evalúa en cada request: `allowed ⟺ count_of_requests_in(now - 60s, now) < 1000`. En este escenario, al minuto `t=60s` la ventana (0s, 60s] contiene 900 + 200 = 1,100 requests. En el momento en que el cliente llega al request #1,001 (que caerá típicamente alrededor de los 50-55s), el contador ya alcanza 1,000 y los siguientes 100 reciben HTTP 429 con header `Retry-After` indicando cuántos segundos esperar hasta que requests viejos salgan de la ventana. Promediar es incorrecto (sliding window es exacto, no estadístico); el gateway no debería encolar (acumularía memoria sin fin y genera latencia desconocida, se delega al cliente con 429 + backoff). Tumbling window (opción 2) permitiría los 1,100 si caen justo entre dos ventanas fijas, pero es menos preciso y permite "burst doubling" al cambio de ventana — por eso se prefiere sliding window en gateways serios (Kong, Envoy ratelimit service, custom con Redis).
