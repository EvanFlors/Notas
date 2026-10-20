# Ejemplo 03 — Dashboard de adopción (y cómo evitar que se vuelva *leaderboard*)

> Lectura y análisis. Objetivo: ver qué publica la plataforma a partir del scorecard y, sobre todo, **qué no publica**.

## 1. La métrica canónica

El dashboard de adopción responde una sola pregunta: *"¿está mejorando la postura global de los servicios?"*. Tres números suficientes:

- **% servicios ≥ bronze**
- **% servicios ≥ silver**
- **% servicios ≥ gold**

Y una serie temporal mensual. Ejemplo (datos sintéticos):

```
         bronze  silver  gold
Ene 2026   92%    48%    12%
Abr 2026   95%    61%    21%
Jul 2026   97%    72%    34%
Oct 2026   98%    78%    41%
```

Lectura: *"la plataforma empuja silver bien (de 48 → 78 % en 9 meses) y gold cuesta más (12 → 41 %). Hora de hacer el chequeo de PSA más fácil."*.

Observa que esto es un **KPI de la plataforma**, no de los equipos. Si no sube, la pregunta es: *"¿qué parte del plato le estamos haciendo difícil al equipo?"*.

## 2. Qué cortes son razonables

Cortes **útiles** y **no venenosos**:

- **Por dominio** (payments, checkout, growth): ayuda a priorizar inversión. *"Payments va bien, Growth está estancado — ¿necesitan golden path mejor?"*
- **Por antigüedad del servicio** (creado hace < 90 días vs ≥ 1 año): mide si los **nuevos** servicios llegan ya en silver (gracias a plantillas) o si siguen rebotando en bronze (plantillas insuficientes).
- **Por nivel de criticidad** (tier-1 vs tier-2): es menos escandaloso que un servicio tier-2 esté en bronze. La **inversión** se concentra en que todos los tier-1 estén en silver o superior.

## 3. Qué cortes son venenosos (y por qué)

- **Ranking público entre equipos.** Dos efectos: (a) los equipos empiezan a optimizar para el chequeo, no para la realidad; (b) el equipo con score bajo se cierra en banda y la cooperación muere.
- **Scorecards por persona.** No tiene sentido conceptual (los servicios no los opera una sola persona) y degenera en evaluación individual encubierta.
- **"Top 10 peores servicios"** en reunión all-hands. Cada aparición en esa lista aleja a su equipo de la plataforma.

Si eliminas estos cortes, pierdes muy poca señal útil y ganas muchísima cooperación.

## 4. Qué se publica para un **equipo**, no para la plataforma

A nivel de equipo lo que se publica es:

- **Su gap personalizado** a silver y a gold: *"a `checkout-api` le faltan 2 chequeos para gold; a `fraud-detector` le falta 1 para silver."*
- **Un enlace al escalation path**: *"para resolver `psa-restricted`, ver [esta guía] / preguntar en #platform."*
- **Tendencia propia**: *"hace 3 meses tenías 2 servicios en silver; hoy 4."*

Nunca se publica: *"estás en el puesto 12 de 18 equipos."* El puesto no mejora la plataforma.

## 5. Cómo se calcula (concretamente)

El `evaluate.py` de la actividad `01-scorecard-for-capstone/` produce un `results.json` con la lista `[ { ref, level, failed_checks }, ... ]`. A partir de ahí la adopción es un cálculo trivial:

```python
total = len(results)
bronze = sum(1 for r in results if r["level"] in ("bronze", "silver", "gold"))
silver = sum(1 for r in results if r["level"] in ("silver", "gold"))
gold   = sum(1 for r in results if r["level"] == "gold")

print(f"bronze: {100*bronze/total:.0f}%")
print(f"silver: {100*silver/total:.0f}%")
print(f"gold:   {100*gold/total:.0f}%")
```

Si tienes Backstage + Tempo/Prometheus + Grafana, lo correcto es exportar estos tres números como gauges periódicos y pintar la serie temporal. Si no, un Markdown mensual publicado en el canal de la plataforma cumple perfectamente.

## 6. Reglas que han aguantado

- **Publícalo mensual, no semanal.** Semanal invita a optimizar para la semana.
- **Publícalo con la lectura ya escrita.** El número suelto se interpreta mal. *"Silver bajó un punto porque incorporamos 4 servicios nuevos; sigue en línea con el objetivo."* desarma pánicos.
- **Celebra bajadas honestas.** Si un chequeo detecta algo real y hace bajar a un servicio, protégelo públicamente. Si lo castigas, el próximo lo esconderá.

## 7. Qué hacer con esto

- Decide, para tu capstone, **qué 3 cortes razonables** publicarías (dominio, tier, antigüedad son los más seguros).
- Decide **qué 2 cortes no publicarías jamás** y por qué.
- Lleva esas decisiones a la actividad `01-scorecard-for-capstone/`, sección "notas de adopción".
