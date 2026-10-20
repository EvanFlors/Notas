# k8s-14-02 — Evaluación comparada de operadores de Postgres

## 1. Identificación
- **ID:** `k8s-14-02-evaluate-postgres-operators`
- **Tecnología:** kubernetes
- **Módulo:** `14-operators-and-crds`
- **Dificultad:** advanced
- **Duración estimada:** 120 min
- **Tipo:** independent

## 2. Contexto

En producción, pocas veces escribirás un operador: casi siempre adoptarás uno existente. La competencia relevante es **saber elegir**. Vas a comparar **CloudNativePG (CNPG)** y **Zalando postgres-operator** con criterios explícitos y emitir una recomendación justificada por contexto.

No hay respuesta universal correcta. Hay respuestas defendibles con criterios y evidencias.

## 3. Objetivos

- Comparar los dos operadores a lo largo de dimensiones predefinidas.
- Emitir una recomendación justificada para **al menos 2 contextos distintos** (p. ej. startup pequeña vs. empresa con 500 clusters).
- Identificar red flags y gaps en cada opción.

## 4. Prerrequisitos

- **Conocimiento**: módulo `k8s-14` leído; actividad 01 completada.
- **Software**: navegador web para leer docs y repos. (Opcional: kind + kubectl si quieres probar los operadores en local; **no es necesario** para completar la actividad.)
- **Costos**: cero.

## 5. Instrucciones

1. Copia `starter/EVALUATION.md` y edítalo (o edita en sitio).
2. Para cada operador, investiga en sus docs oficiales y repo:
   - **CloudNativePG**: https://cloudnative-pg.io/documentation/ · https://github.com/cloudnative-pg/cloudnative-pg
   - **Zalando postgres-operator**: https://postgres-operator.readthedocs.io/ · https://github.com/zalando/postgres-operator
3. Rellena la tabla comparativa y cada sección narrativa.
4. En la última sección da **recomendaciones por contexto**: no copies "depende"; defiende cada elección con 2–3 criterios concretos.
5. **No reveles la solución** antes de intentar — el documento `solution/EVALUATION-reference.md` existe solo como referencia a posteriori.

Esta actividad es **independiente**: no hay guía paso a paso.

## 6. Resultado esperado

Un documento `starter/EVALUATION.md` relleno con:
- Tabla comparativa completa (10 filas mínimas).
- Secciones narrativas: madurez, blast radius, backup/restore, upgrade story, licencia & comunidad, red flags.
- Al menos 2 recomendaciones contexto-dependientes.
- Sin marcadores `TODO (student)`.

## 7. Criterios de aceptación

- Criterios **explícitos** (no vibes): "soporta backup incremental a S3 nativamente" es un criterio; "me gusta más" no.
- Evidencias con referencia (URL, versión, fecha de consulta).
- Recomendación coherente con los criterios declarados.
- Reconocer limitaciones de la propia evaluación (p. ej. "no probé failover real; solo leí docs").

## 8. Validación

```bash
bash tests/validate.sh
```

Verifica que `EVALUATION.md` tiene las secciones requeridas y no deja TODOs. La **calidad del contenido** se evalúa de forma manual con la rúbrica en el README del módulo.

## 9. Preguntas de reflexión

1. ¿Qué peso le darías a "comunidad activa" vs "soporte comercial" en tu contexto?
2. ¿Qué métricas operativas pedirías a cada operador antes de aprobar la adopción?
3. ¿Qué estrategia tendrías para **salir** del operador si deja de mantenerse?
4. ¿Cambia tu recomendación si el requisito es Postgres en **edge** (clusters pequeños, muchos sitios)?
5. Un tercer competidor que no está en la comparación: **Crunchy PGO**. ¿Qué agregarías?

## 10. Extensiones

- Añade una tercera columna con **Crunchy PGO**.
- Instala ambos en kind y haz un **failover test** con cada uno; documenta tiempos y comportamiento.
- Escribe un ADR corto estilo "Nygard" con la decisión y sus consecuencias.

## 11. Limpieza

Esta actividad no crea recursos. Nada que limpiar salvo clusters locales si los creaste para pruebas opcionales.
