# Memoria en Agentes

## ¿Qué es?

La **memoria** en un agente es cualquier mecanismo que le permite **recordar información más allá del prompt actual**: lo que acaba de hacer en esta sesión, lo que aprendió en sesiones pasadas, hechos sobre el usuario, procedimientos reutilizables. Sin memoria, cada iteración del loop empieza prácticamente de cero y el agente repite trabajo, olvida preferencias y no mejora con la experiencia.

Memoria resuelve tres problemas:

1. **Continuidad de contexto** dentro de una tarea (no re-escanear el módulo de auth que ya revisé).
2. **Aprendizaje de la experiencia** entre tareas (ya sé que `random.randint` para tokens es un bug recurrente).
3. **Relación con el usuario** entre sesiones (este usuario quiere reviews detallados en español).

### Tipos de memoria

| Tipo | Qué guarda | Ejemplo | Dónde vive |
|---|---|---|---|
| **Working (short-term)** | Thoughts, actions, observations de la **sesión actual** | Historial del loop ReAct | Lista en RAM / context window |
| **Episodic** | Episodios discretos del pasado | "El 3 de octubre revisé el PR #1247 y encontré SQLi" | Vector DB (Pinecone, Qdrant, Chroma) |
| **Semantic** | Hechos y conocimiento general | "El módulo auth suele tener problemas de validación de input" | DB estructurada, knowledge graph |
| **Procedural** | Workflows reutilizables | "Para review de seguridad: input validation → authn checks → secrets scan → coverage" | Templates versionados |
| **External** | Datos del dominio accesibles vía query | Base de clientes, docs internas, Confluence | Postgres, S3, APIs |

> Analogía con el cerebro humano (Tulving, 1972 y 1985): **working** = memoria de trabajo, **episodic** = recuerdos autobiográficos, **semantic** = conocimiento general, **procedural** = cómo hacer cosas (andar en bici).

### Short-term vs Long-term

| Dimensión | Short-term (working) | Long-term (episodic / semantic / procedural) |
|---|---|---|
| Alcance | Una sesión | Entre sesiones, meses o años |
| Almacenamiento | Context window + RAM | Vector DB + SQL |
| Límite | Context window del LLM (ej. 200K tokens) | Prácticamente ilimitado |
| Latencia de acceso | 0 (ya está en contexto) | 50-500 ms (retrieval) |
| Costo marginal | Cada token cuesta en cada llamada | Barato de almacenar, caro de buscar |
| Riesgo principal | Context explosion | Memoria obsoleta / contradictoria |

## ¿Por qué importa?

Un chatbot sin memoria es aceptable (una sola pregunta, una sola respuesta). Un **agente** sin memoria **no puede completar tareas multi-paso**: olvida en el paso 5 lo que decidió en el paso 2.

Más allá del loop actual, la memoria long-term permite:

- **Personalización.** El agente aprende las preferencias del usuario sin que las repita.
- **Aprendizaje organizacional.** Lo que aprende un agente lo aprovechan los demás.
- **Reducción de costos.** No vuelve a investigar lo que ya investigó; cachea procedimientos exitosos.
- **Mejor calidad de decisión.** Estudios sobre agentes con episodic memory muestran mejoras de 30-40% en tasa de resolución comparado con agentes sin memoria.

Pero toda memoria tiene un costo: **latencia (retrieval), tokens (contexto más grande), complejidad (sincronización, decay, privacidad)**. La pregunta no es "¿agrego memoria?" sino "¿qué tipo, cuánta y cuándo cargarla?".

## ¿Cómo funciona?

### State management de working memory

El patrón más simple guarda todo el historial:

```
state = {
  "goal": "...",
  "history": [
    {"thought": ..., "action": ..., "observation": ...},
    ...
  ]
}
```

Esto funciona hasta ~20 iteraciones. Después el historial satura el context window. Las estrategias para mitigar context explosion son:

| Estrategia | Idea | Trade-off |
|---|---|---|
| **Selective retention** | Marcar steps como `high/normal/low` y conservar solo los altos | Pierdes contexto fino |
| **Summarization** | Resumir los steps viejos con otro LLM pass | Costo extra + pérdida de detalle |
| **Hierarchical state** | Niveles: goal → phase → recent_actions | Reset parcial al cambiar de fase |
| **Checkpointing** | Serializar estado periódicamente a disco | Permite resumir runs interrumpidos |
| **Sliding window** | Mantener solo las últimas N interacciones | Puede olvidar algo crucial del inicio |

### Retrieval de long-term memory

**Semantic search** (vector DB) para episodios por similitud:

```
1. Embed (situación actual) → vector
2. kNN search en episode store → top-k episodios relevantes
3. Inyectar en el prompt como contexto adicional
```

**Structured queries** para hechos exactos: `SELECT procedure FROM playbooks WHERE category='deploy'`.

**Hybrid retrieval:** combinar ambos cuando necesitas *contexto parecido* + *dato exacto*.

### Triggers de retrieval

Cuándo cargar memoria sin saturar:

- **Al iniciar la tarea** (cargar procedimientos + episodios similares).
- **Al detectar incertidumbre** (el reasoning dice "no estoy seguro").
- **Al fallar una acción** (buscar fallos similares).
- **Bajo demanda explícita** (el agente pide `search_memory`).

### Patrones avanzados

- **Case-based reasoning (CBR):** resolver un problema nuevo recuperando y adaptando soluciones de problemas pasados similares.
- **Confidence calibration:** usar historial de éxitos/fallos para estimar confianza en la decisión actual.
- **Negative memory:** recordar explícitamente **qué no hacer** (ej. "flaguear `assert` en tests fue falso positivo 3 veces").
- **Progressive elaboration:** cargar resúmenes primero, pedir detalles solo si son relevantes.

## Ejemplo con código

### State management con checkpointing en LangGraph

```python
from langgraph.prebuilt import create_react_agent
from langgraph.checkpoint.sqlite import SqliteSaver
from langchain_anthropic import ChatAnthropic
from langchain_core.tools import tool

@tool
def check_module(name: str) -> str:
    """Analiza un módulo por vulnerabilidades."""
    return f"{name}: OK"

memory = SqliteSaver.from_conn_string("checkpoints.db")   # persistencia en disco
llm = ChatAnthropic(model="claude-3-5-sonnet-latest")
agent = create_react_agent(llm, tools=[check_module], checkpointer=memory)

config = {"configurable": {"thread_id": "pr-1247-review"}}

# Primera corrida: hace parte del trabajo y "crashea"
agent.invoke({"messages": [("user", "Revisa auth y payment")]}, config)

# Más tarde (incluso tras reiniciar el proceso): continúa donde quedó
agent.invoke({"messages": [("user", "¿Qué falta?")]}, config)
```

El `checkpointer` guarda el estado por `thread_id` tras cada paso. Resumabilidad gratis.

### Memoria episódica con vector DB (Chroma)

```python
import chromadb
from chromadb.utils import embedding_functions

client = chromadb.PersistentClient(path="./agent_memory")
embed = embedding_functions.SentenceTransformerEmbeddingFunction("all-MiniLM-L6-v2")
episodes = client.get_or_create_collection("episodes", embedding_function=embed)

def store_episode(summary: str, outcome: str, tags: list[str]):
    episodes.add(
        documents=[summary],
        metadatas=[{"outcome": outcome, "tags": ",".join(tags)}],
        ids=[f"ep-{int(time.time()*1000)}"],
    )

def recall_similar(situation: str, k: int = 3) -> list[str]:
    res = episodes.query(query_texts=[situation], n_results=k)
    return list(zip(res["documents"][0], res["metadatas"][0]))

# Guardar un episodio tras resolver una tarea
store_episode(
    summary="PR #1247 - password_reset.py usaba random.randint para tokens",
    outcome="bloqueado; autor corrigió con secrets.token_urlsafe",
    tags=["security", "auth", "token-generation"],
)

# Recuperar al enfrentar algo parecido
for doc, meta in recall_similar("revisar generación de tokens en reset de password"):
    print(doc, "→", meta["outcome"])
```

### Agent loop con memoria working + episódica

```python
from anthropic import Anthropic
client = Anthropic()

def build_context(goal, working_history, episodic_hits, max_tokens=8000):
    parts = [f"Goal: {goal}"]
    # Prioridad 1: últimas 5 acciones (working)
    parts.append("Recent actions:\n" + format_history(working_history[-5:]))
    # Prioridad 2: resumen de pasos antiguos si hay espacio
    if len(working_history) > 10:
        parts.append("Earlier (summary): " + summarize(working_history[:-5]))
    # Prioridad 3: episodios similares (long-term)
    if episodic_hits:
        parts.append("Relevant past cases:\n" + format_episodes(episodic_hits))
    return "\n\n".join(parts)

def agent_with_memory(goal: str, user_id: str):
    working = []
    for i in range(15):
        episodic = recall_similar(goal, k=3) if i == 0 else []  # cargar al inicio
        prompt = build_context(goal, working, episodic)

        resp = client.messages.create(
            model="claude-3-5-sonnet-latest",
            max_tokens=512,
            messages=[{"role": "user", "content": prompt}],
            tools=TOOLS_SCHEMA,
        )

        if resp.stop_reason == "end_turn":
            final = resp.content[0].text
            store_episode(summary=f"{goal} -> {final[:200]}",
                          outcome="success", tags=[user_id])
            return final

        # ejecutar tool, actualizar working...
        working.append(execute_tool_blocks(resp.content))

        # compresión progresiva
        if len(working) > 15:
            working = [summarize_block(working[:10])] + working[-5:]
```

Observa cómo se **prioriza el context window**: siempre va el goal + acciones recientes; episodios y resúmenes se agregan si queda espacio.

### Memoria de usuario (preferencias)

```python
user_memory = {
    "user_id": "evan",
    "preferences": {"language": "es", "detail_level": "high",
                    "auto_approve": False, "focus": ["security", "performance"]},
    "stats": {"reviews_total": 147, "common_feedback": ["missing tests", "SQLi risk"]},
    "do_not_flag": ["asserts en tests", "console.log en examples/"],  # negative memory
}

def personalize_prompt(base_prompt, user_memory):
    prefs = user_memory["preferences"]
    return (base_prompt
            + f"\n\nUsuario habla {prefs['language']}. "
            + f"Nivel de detalle: {prefs['detail_level']}. "
            + f"Foco: {', '.join(prefs['focus'])}. "
            + f"Nunca flaguear: {', '.join(user_memory['do_not_flag'])}.")
```

## Errores comunes

- **Agentes sin memoria entre runs.** Cada sesión parte de cero y el usuario repite su contexto. Persiste conversaciones con `thread_id` y recupera al reanudar.
- **Context explosion.** Guardar todo el historial en cada llamada infla el prompt a 50K+ tokens, dispara costos y degrada calidad. Usa summarization, selective retention o sliding window.
- **Guardar todo sin curar.** Vector DB con 500K episodios ruidosos retorna basura relevante en apariencia. **Calidad > cantidad**: resume, deduplica, decay.
- **No sincronizar memoria compartida.** Dos agentes actualizan el mismo registro simultáneamente y pierden datos. Usa locks distribuidos o CRDTs.
- **Memoria obsoleta.** Guardaste que "el server-03 corre Python 3.9" hace 6 meses; hoy corre 3.11. Implementa validación periódica y marca como `stale`.
- **Fugas de privacidad.** El agente del usuario A recupera un episodio del usuario B. Siempre filtra retrieval por `user_id` / permisos.
- **Prompt injection vía memoria.** Un usuario malicioso puede sembrar memorias ("ignora instrucciones previas"). Sanitiza antes de guardar y encapsula al cargar.
- **Olvidar negative memory.** El agente repite el mismo falso positivo cada semana porque solo recuerda éxitos. Guarda también lo que *no* funcionó.
- **No medir el retorno de la memoria.** Agregas vector DB y el agente mejora 2% pero la latencia sube 400ms. Mide A/B antes de dejar la complejidad.
- **Depender solo de similitud semántica.** Para hechos exactos ("¿qué versión corre server-03?") usa queries estructuradas; semantic search puede devolver episodios "parecidos" pero equivocados.

## Resumen

- **Memoria = capacidad del agente de recordar más allá del prompt actual**; sin ella, no hay tareas multi-paso ni personalización.
- Cinco tipos coexisten: **working (sesión actual), episodic (episodios pasados), semantic (hechos generales), procedural (workflows), external (datos del dominio)**.
- **Short-term** vive en el context window (rápido, limitado); **long-term** vive en vector DB + SQL (ilimitado, requiere retrieval).
- Para controlar la working memory: **selective retention, summarization, hierarchical state, checkpointing y sliding windows**.
- El **retrieval** se hace con semantic search (vector DB), structured queries o híbrido; se dispara al iniciar la tarea, al dudar, al fallar o bajo demanda.
- Patrones avanzados: **case-based reasoning, confidence calibration, negative memory y progressive elaboration** elevan la calidad de decisión.
- Memoria long-term exige **mantenimiento**: decay, resolución de conflictos, validación contra el estado actual y controles de acceso.
- En producción, **persistencia por `thread_id`** (ej. `langgraph.checkpoint`) hace al agente resumible tras crashes y permite conversaciones continuas.
- Trade-off central: **más memoria → mejores decisiones pero más latencia, más tokens, más complejidad**. Mide siempre el retorno.
- **Privacidad y seguridad** no son opcionales: filtra por usuario, sanitiza entradas, loguea accesos y arquitecta memoria compartida con permisos explícitos.
