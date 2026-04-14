Genera el código del frontend utilizando ReactJS, TailwindCSS y Material UI.

La aplicación debe ser una interfaz web tipo Kanban, inspirada en un diseño minimalista similar a Notion, que consuma la API local previamente construida.

Estructura de la Interfaz

La interfaz principal debe mostrar un tablero dividido en tres columnas:

- To Do
- In Progress
- Done

Cada columna debe contener tarjetas de tareas correspondientes a su estado.

Componentes Requeridos

Crea componentes reutilizables y bien estructurados, incluyendo:

Board → contenedor principal del tablero
Column → representa cada estado (To Do, In Progress, Done)
TaskCard → tarjeta individual de tarea
Toolbar → barra superior con acciones
CreateTaskModal → modal para crear nuevas tareas
FilterDropdown → filtro por estado
SortDropdown → ordenamiento por fecha
CommentSection → sección de comentarios dentro de cada tarea
ProgressBar → barra de progreso general del tablero

Funcionalidades

La aplicación debe implementar:

1. Gestión de tareas
- Crear una nueva tarea (modal con formulario)
- Mostrar tareas obtenidas desde la API
- Actualizar el estado de una tarea

2. Filtros y ordenamiento
- Filtrar tareas por estado
- Ordenar tareas por fecha de creación (ascendente/descendente)

3. Interacción
- Drag & Drop entre columnas (usar librería como dnd-kit o react-beautiful-dnd)
- Visual feedback al arrastrar

4. Comentarios
- Agregar comentarios dentro de cada tarea
- Mostrar lista de comentarios por tarea
5.  Progreso
- Mostrar una barra de progreso general:
  - % basado en tareas completadas vs totales

6. Estilo y Diseño
- Diseño minimalista tipo Notion
- Uso de:
    - Colores suaves y neutros
    - Espaciado amplio
    - Bordes redondeados
    - Sombras sutiles
    - UI limpia, sin sobrecarga visual
    - Responsive (adaptable a diferentes tamaños de pantalla)

7. Integración con API
- Consumir endpoints REST (GET, POST, PATCH, etc.)
- Manejo de estados con hooks (useState, useEffect) o contexto
- Manejo de loading y errores

8. Buenas prácticas
- Separación de componentes
- Código limpio y reutilizable
- Uso de hooks personalizados cuando sea necesario
- Manejo adecuado del estado global (Context API o similar)

9. Extras (opcional pero recomendado)
- Animaciones suaves (hover, drag)
- Skeleton loaders
- Confirmaciones visuales (snackbar/toast de Material UI)