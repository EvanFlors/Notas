# Retención, auditoría y procedencia

## ¿Qué es?

**Retención** es la política que define cuánto tiempo se conserva cada clase de dato antes de ser destruida. **Auditoría** es el registro inalterable de qué ocurrió, cuándo y por quién, usable como evidencia frente a reguladores. **Procedencia (provenance)** es el linaje que conecta cada output del LLM con el prompt exacto, el modelo, la configuración y el contexto que lo produjeron.

Las tres piezas forman la **memoria operativa** de un sistema de IA en producción:

> **Retención** = ¿qué se guarda y por cuánto?
> **Auditoría** = ¿qué pasó y quién lo hizo?
> **Procedencia** = ¿cómo se produjo este output específicamente?

Sin las tres, un incidente deja de ser investigable y una regulación deja de ser cumplible.

### El "shadow dataset" de las herramientas de IA

Cada vez que un asistente procesa un prompt, nace un rastro:

- El **prompt** (lo que el usuario envió).
- La **respuesta** del modelo.
- Los **tool calls** si el agente usó herramientas.
- Los **metadatos** (modelo, temperatura, latencia, tokens).
- La **telemetría** (errores, timings).

Multiplica eso por miles de interacciones diarias y tienes un **lago de datos sombra** que casi siempre contiene PII residual, incluso después de redactar. Este dataset es tan sensible como la base de clientes de producción, pero rara vez se gestiona con el mismo rigor.

### Tiered retention por clasificación

| Clasificación | Prompts crudos | Outputs | Métricas agregadas | Provenance |
|---|---|---|---|---|
| **Restricted** | 0 días (no se guarda) | 0 días | 90 días | 1 año |
| **Confidential** | 7 días | 30 días | 180 días | 1 año |
| **Internal** | 30 días | 90 días | 365 días | 2 años |
| **Public** | 90 días | 180 días | Indefinido | Indefinido |

Esta tabla no es universal, pero es un punto de partida razonable. GDPR Art. 5(1)(e) exige **storage limitation**: el dato se conserva "solo lo necesario". HIPAA pide 6 años para registros médicos. Cada tier debe mapearse a una regulación aplicable.

## ¿Por qué importa?

**Caso real:** en 2024 una fintech europea recibió un **DSAR** (Data Subject Access Request) de un cliente invocando GDPR Art. 17 ("right to erasure"). El cliente pidió borrar todo rastro de su información. El equipo pudo borrarlo de la BD transaccional, de los backups y de los CRMs… pero descubrió que su asistente de soporte había cacheado 3,000 conversaciones con el email del cliente en S3 **sin TTL**. Resultado: 72 horas de panic engineering para construir un workflow de borrado retrospectivo, bajo riesgo de multa.

### Las tres funciones del audit log

1. **Incident response.** Cuando hay fuga, el audit log es la primera parada: ¿qué entró, qué salió, cuándo?
2. **Reproducibility.** Un bug reportado hace una semana solo se puede reproducir si tienes la combinación exacta de prompt + modelo + versión + contexto.
3. **Compliance evidence.** Auditores GDPR/HIPAA/SOC2 piden evidencia de controles: logs de acceso, pruebas de deletion, retention schedules aplicados.

### Procedencia como "lockfile" de la IA

En software determinístico tienes `package-lock.json`: cualquiera puede reproducir el build exacto. En IA el equivalente es un **provenance tag** que contiene:

- `prompt_template_id` + versión
- `context_manifest_id` (hash del conjunto de documentos retrieved)
- `model_name` + versión + parámetros (`temperature`, `top_p`, `seed`)
- Timestamp y actor

Con eso se puede re-ejecutar la decisión semanas después (modulo la no-determinismo residual del modelo).

## ¿Cómo funciona?

### Esquema de audit log

Un entry mínimo pero completo:

```json
{
  "event_id": "evt_01HXYZ...",
  "ts": "2025-10-07T14:32:11Z",
  "actor": {"type": "user", "id": "eng_42", "sso": "okta|john"},
  "action": "llm_request",
  "input": {
    "sha256": "a3f7...",
    "length": 1234,
    "classification": "confidential",
    "redactions": {"EMAIL_ADDRESS": 2, "PERSON": 1}
  },
  "model": {"name": "claude-sonnet-4-5", "temperature": 0.3},
  "provenance": {
    "prompt_template_id": "support_debug_v3",
    "context_manifest_id": "ctx_8f9e..."
  },
  "policy": {"region": "eu-west-1", "zdr": true},
  "output": {"sha256": "b6c1...", "tokens": 342},
  "integrity_hmac": "e4d9..."
}
```

### Workflow DSAR (Data Subject Access Request)

GDPR Art. 15 obliga a entregar al titular toda su información; Art. 17 obliga a borrarla a petición. Para herramientas de IA el workflow es:

```
Usuario pide erasure (ej. ana@acme.com)
     │
     ▼
1. Buscar en audit log todos los eventos con hash(email_crudo)
   coincidente con hash(ana@acme.com)
     │
     ▼
2. Para cada evento → localizar artefactos (prompt cifrado,
   output cifrado, contexto retrieved)
     │
     ▼
3. Borrar artefactos (overwrite + delete) y marcar
   evento con "erased=true, erasure_ts=..."
     │
     ▼
4. Notificar al proveedor LLM (si hay prompts no-ZDR,
   abrir ticket de deletion con vendor)
     │
     ▼
5. Confirmar al titular con reporte firmado
```

### Logs tamper-evident

Append-only + hash chain (estilo blockchain simplificado o AWS CloudTrail digest):

```
entry_n.hmac = HMAC(key, entry_n.body || entry_{n-1}.hmac)
```

Cualquier modificación histórica rompe la cadena. Alternativas production-grade:
- **AWS CloudTrail Lake** con integrity validation.
- **GCP Cloud Audit Logs** con digests firmados.
- **Immudb** / **QLDB** (ledger databases).

## Ejemplo con código

### Audit log con HMAC chain

```python
# pip install cryptography
import hashlib, hmac, json, os
from datetime import datetime
from pathlib import Path

AUDIT_KEY = os.environ["AUDIT_HMAC_KEY"].encode()  # en KMS en producción
LOG_PATH = Path("/var/log/ai/audit.jsonl")

def _last_hmac() -> str:
    if not LOG_PATH.exists():
        return "0" * 64
    with LOG_PATH.open("rb") as f:
        f.seek(0, 2)
        size = f.tell()
        f.seek(max(0, size - 4096))
        last = f.read().splitlines()[-1]
    return json.loads(last)["hmac"]

def audit(event: dict) -> dict:
    event.setdefault("ts", datetime.utcnow().isoformat() + "Z")
    body = json.dumps(event, sort_keys=True).encode()
    chain_input = body + _last_hmac().encode()
    event["hmac"] = hmac.new(AUDIT_KEY, chain_input, hashlib.sha256).hexdigest()
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("a") as f:
        f.write(json.dumps(event, sort_keys=True) + "\n")
    return event

def verificar_cadena() -> bool:
    prev = "0" * 64
    with LOG_PATH.open() as f:
        for linea in f:
            e = json.loads(linea)
            saved = e.pop("hmac")
            body = json.dumps(e, sort_keys=True).encode()
            esperado = hmac.new(AUDIT_KEY, body + prev.encode(),
                                 hashlib.sha256).hexdigest()
            if esperado != saved:
                return False
            prev = saved
    return True
```

### Provenance tagging y verificación

```python
from dataclasses import dataclass, asdict, field
from typing import Any
import hashlib, json, uuid
from datetime import datetime

@dataclass
class ProvenanceTag:
    change_id: str
    prompt_template_id: str
    prompt_template_version: str
    context_manifest_id: str
    model_name: str
    model_config: dict[str, Any]
    actor: str
    ts: str = field(default_factory=lambda:
                    datetime.utcnow().isoformat() + "Z")

    def fingerprint(self) -> str:
        payload = json.dumps(asdict(self), sort_keys=True).encode()
        return hashlib.sha256(payload).hexdigest()[:16]


class ProvenanceStore:
    def __init__(self):
        self._store: dict[str, ProvenanceTag] = {}

    def tag(self, **kw) -> ProvenanceTag:
        tag = ProvenanceTag(change_id=kw.pop("change_id",
                                              f"chg_{uuid.uuid4().hex[:12]}"),
                            **kw)
        self._store[tag.change_id] = tag
        audit({"action": "provenance_tagged",
               "change_id": tag.change_id,
               "fingerprint": tag.fingerprint()})
        return tag

    def reproducible(self, change_id: str) -> bool:
        tag = self._store.get(change_id)
        if not tag:
            return False
        requeridos = [tag.prompt_template_id, tag.prompt_template_version,
                      tag.context_manifest_id, tag.model_name]
        return all(requeridos)
```

### Handler DSAR (right to erasure, GDPR Art. 17)

```python
import hashlib, json
from pathlib import Path

ARTEFACTOS = Path("/var/lib/ai-cache")

def hash_pii(valor: str) -> str:
    return hashlib.sha256(valor.lower().strip().encode()).hexdigest()

def dsar_erasure(subject_email: str, ticket_id: str) -> dict:
    h = hash_pii(subject_email)
    borrados = []

    # 1. Localizar eventos de audit que correlacionen
    with Path("/var/log/ai/audit.jsonl").open() as f:
        for linea in f:
            evento = json.loads(linea)
            if evento.get("subject_hash") == h:
                # 2. Borrar artefactos físicos (overwrite + delete)
                for sha in [evento["input"]["sha256"],
                            evento["output"]["sha256"]]:
                    archivo = ARTEFACTOS / f"{sha}.enc"
                    if archivo.exists():
                        archivo.write_bytes(b"\x00" * archivo.stat().st_size)
                        archivo.unlink()
                        borrados.append(sha)

    # 3. Registrar la erasure (evento append-only, nunca se borra)
    reporte = {
        "action": "dsar_erasure",
        "ticket_id": ticket_id,
        "subject_hash": h,
        "artefactos_borrados": borrados,
        "regulation": "GDPR Art. 17",
    }
    audit(reporte)

    # 4. Marcar en vendor (si no hay ZDR)
    # vendor_client.deletion_request(subject_hash=h)   # pseudo-API

    return reporte
```

### Retention sweeper

Un cron job que aplica el schedule:

```python
import time
from pathlib import Path

TIERS = {
    "restricted":   {"prompts": 0,    "outputs": 0,    "metrics": 90},
    "confidential": {"prompts": 7,    "outputs": 30,   "metrics": 180},
    "internal":     {"prompts": 30,   "outputs": 90,   "metrics": 365},
    "public":       {"prompts": 90,   "outputs": 180,  "metrics": None},
}

def barrer_retencion(base: Path = Path("/var/lib/ai-cache")) -> None:
    ahora = time.time()
    for archivo in base.rglob("*.enc"):
        # Convención de path: {clasif}/{tipo}/{sha}.enc
        clasif, tipo, _ = archivo.relative_to(base).parts
        max_dias = TIERS[clasif].get(tipo)
        if max_dias is None:
            continue
        edad_dias = (ahora - archivo.stat().st_mtime) / 86400
        if edad_dias > max_dias:
            archivo.write_bytes(b"\x00" * archivo.stat().st_size)
            archivo.unlink()
            audit({"action": "retention_delete",
                   "path": str(archivo),
                   "age_days": round(edad_dias, 1),
                   "policy": f"{clasif}/{tipo}:{max_dias}"})
```

### Retention en entornos multi-tenant

Cada tenant puede tener políticas distintas (regulación distinta, contrato distinto):

```yaml
retention:
  default:
    prompts: 7
  overrides:
    tenant_eu_bank:   { prompts: 1,  outputs: 7 }   # banca UE estricta
    tenant_marketing: { prompts: 30, outputs: 90 }  # permisivo
    tenant_health:    { prompts: 0,  outputs: 0 }   # HIPAA sin PHI residual
```

## Errores comunes

- **Guardar todo "por si acaso".** Sin TTL explícito, los prompts crudos acumulan PII durante años, convirtiéndose en un honeypot regulatorio.
- **Logs crudos sin redacción.** Un audit log con el prompt original anula todo el pipeline de redacción. Guarda **hashes** del input, no el input.
- **No tamper-evidence.** Un audit log mutable es evidencia débil ante auditoría; cualquier insider puede modificarlo. Usa append-only + HMAC chain o ledger database.
- **Olvidar los backups.** La política dice "borramos tras 30 días", pero los snapshots nocturnos conservan los prompts 2 años. GDPR Art. 17 aplica también a backups (con excepciones acotadas).
- **Sin workflow DSAR.** Cuando llega la primera erasure request, no hay forma técnica de localizar y borrar los artefactos. Diseña el DSAR **antes** de recibirlo.
- **No distinguir tenants.** Aplicar la misma retención a un dataset de salud (HIPAA, 6 años) y a uno de marketing confunde los dos extremos: incumples uno y gastas de más en el otro.
- **Provenance opcional.** Si el tag es manual, los desarrolladores lo omiten bajo presión. Hazlo obligatorio en el PR template o bloquea el merge.
- **No verificar la cadena de HMAC** periódicamente. Un audit log corrupto que nadie revisa es tan inútil como no tenerlo.
- **Confundir soft-delete con delete.** `UPDATE ... SET deleted=1` no cumple Art. 17; hace falta destrucción física o cripto-shredding (destruir la clave de cifrado).
- **No notificar al vendor.** Si el proveedor no tiene ZDR, borrar tus copias no basta; hay que abrir ticket de deletion con el vendor (OpenAI, Anthropic ofrecen formularios).
- **Retention de datasets de evaluación.** Los eval sets suelen contener datos reales de incidentes pasados; aplícales la misma política que a prompts.

## Resumen

- **Retención, auditoría y procedencia** son la memoria operativa de un sistema IA: definen qué se guarda, qué pasó y cómo reproducirlo.
- Las herramientas de IA generan un **shadow dataset** (prompts, outputs, tool calls, telemetría) tan sensible como la BD de producción; gestiónalo con el mismo rigor.
- **Tiered retention** por clasificación: Restricted se destruye inmediatamente; Public puede guardarse indefinidamente. Alinea TTL con regulación aplicable (GDPR, HIPAA, PCI-DSS).
- Un **audit log** útil incluye timestamp, actor, hash del input, modelo, provenance, y HMAC chain para tamper-evidence.
- **Procedencia** = `prompt_template_id` + versión + `context_manifest_id` + modelo + config: es el "lockfile" que permite reproducir un output semanas después.
- **DSAR workflow** (GDPR Art. 17): hashea PII en el audit, correlaciona por hash, destruye artefactos cifrados, notifica al vendor si no hay ZDR, registra la erasure.
- **Tamper-evident logs** vía HMAC chain, AWS CloudTrail Lake, GCP Cloud Audit Logs o ledger DBs (QLDB, Immudb) son requisito para evidencia regulatoria.
- **Retention sweeper** automatizado aplica el schedule sin intervención; manual = olvidado.
- **Multi-tenant retention** requiere overrides por tenant: salud (HIPAA), banca UE y marketing tienen regímenes distintos.
- **Provenance como gate**: si el PR no incluye tag, no se mergea. Hazlo obligatorio en PR templates o CI.
- **Nunca** guardes el prompt crudo en el audit log: guarda el hash + metadatos + copia cifrada en storage separado con TTL propio.
