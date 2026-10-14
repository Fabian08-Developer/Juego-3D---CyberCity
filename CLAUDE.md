# Instrucciones para Claude

- Trabajar siempre en la rama `main`: hacer commit y push directamente a `main` (decisión del dueño del repositorio).
- Responder en español.
- Proyecto Godot 4.4+ con GDScript. Antes de hacer push:
  - `gdlint scripts`
  - `godot --headless --path . -- --smoke-test` (debe terminar con "TODO OK").
  - Si se agregan scripts con `class_name` nuevos, ejecutar antes `godot --headless --path . --import`.
- El contenido editable (negocios, incidentes, eventos) está en `data/*.json`.
