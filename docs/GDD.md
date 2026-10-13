# CyberCity — Documento de Diseño (GDD) y Hoja de Ruta

## 1. Visión

Juego 3D en primera y tercera persona que combina **exploración urbana** con **simulación profesional de
ciberseguridad**. El jugador vive la rutina de un(a) Ingeniero(a) en Ciberseguridad: llega al trabajo, atiende alertas
reales (basadas en CVE y técnicas MITRE ATT&CK auténticas), resuelve situaciones de seguridad en la calle, gestiona su
energía y construye su carrera.

**Pilares**

1. **Realismo educativo**: cada reto enseña algo verdadero (Heartbleed, Log4Shell, BEC, LOLBins, viaje imposible, evil twin…).
2. **Presión de tiempo con agencia**: las alertas tienen plazo; el jugador decide cuándo salir a la ciudad y cuándo volver.
3. **Una ciudad con vida**: negocios recorribles, tráfico con semáforos, peatones, día y noche.
4. **Contenido editable sin programar**: negocios, retos y eventos viven en JSON.

**Público**: estudiantes y profesionales de TI, entusiastas de la ciberseguridad, formación y concientización.

## 2. Tecnología

**Godot 4.4+ con GDScript** (renderizador Forward+).

- Motor completo y libre: editor visual, física, iluminación, partículas, exportación a Windows/Linux/macOS/Android/Web.
- GDScript es sencillo de aprender (parecido a Python).
- El prototipo inicial en Three.js se conserva en `prototipo-web/` como referencia.

Toda la geometría y las texturas se generan por código: el proyecto no depende de assets externos y abre en segundos.
El siguiente salto visual es sustituir piezas por modelos glTF (ver Fase 3).

## 3. Mecánicas actuales (v0.2)

### Movimiento y cámara
- `CharacterBody3D` con primera y tercera persona (`V`); cámara de hombro con `SpringArm3D` (no atraviesa paredes).
- Correr, saltar, subir bordillos (step-up propio), zoom con la rueda, cuerpo visible solo como sombra en 1ª persona.

### Ciudad
- Cuadrícula 3×3 (manzanas de 40 m, calles de 12 m): parque central con fuente de partículas, sede CyberShield al
  norte, calle comercial alrededor del parque, residencias y la casa del jugador al sur.
- **9 negocios con interior**: puertas automáticas, mostrador con cajero(a), y mobiliario según su estilo
  (`shelves`, `tables`, `bank`, `books`, `tech`). Cada uno vende productos con efectos (energía, reputación, XP) y da un
  tip de seguridad.
- **Tráfico**: 32 vehículos (sedán, SUV, taxi, bus) en carriles de doble sentido, **16 intersecciones con semáforo**
  (ciclo verde/amarillo/todo rojo), distancia de seguimiento y frenado ante el jugador.
- Peatones en aceras y paseantes en el parque; farolas, árboles, hidrantes, paradas de bus, colinas en el horizonte.
- **Día/noche**: el sol recorre el cielo (06:00–18:30), atardecer, y de noche se encienden farolas, ventanas, letreros y faros.

### CyberShield
- Lobby (recepción, torniquetes, ascensores), oficina abierta con compañeros con los que se puede hablar, cuarto de
  servidores, sala de reuniones con pizarra NIST, muro del SOC con pantallas en vivo y estación de trabajo del jugador.

### Incidentes del SOC

| Categoría | Nivel mínimo | Ejemplos de lo que se debe detectar |
| --- | --- | --- |
| Phishing | 1 | Homógrafos, subdominios engañosos, fraude del CEO, adjuntos con macros |
| Malware | 1 | svchost fuera de System32, PowerShell `-enc` desde Word, criptominero, doble extensión |
| Vulnerabilidades | 1 | Apache 2.4.49, OpenSSL 1.0.1f, Log4j 2.14.1, SMBv1, vsftpd 2.3.4, Redis sin auth |
| Contraseñas | 1 | Contraseñas filtradas o predecibles, sin MFA, cuentas de servicio sin rotación |
| Intrusión | 2 | Fuerza bruta + éxito, cuentas creadas, logs borrados, viaje imposible |
| Firewall | 2 | Reglas any-any, SMB/RDP/MySQL/Telnet expuestos |
| Ransomware | 3 | Borrado de shadow copies y catálogo de backups, cifrado masivo, nota de rescate, PsExec |

Flujo: **marcar elementos → elegir la respuesta → revisión con explicación de cada fila**.
Puntaje = 70 % clasificación + 30 % respuesta. Pago, reputación y XP escalan con la severidad
(Baja ×0.8 … Crítica ×1.5). Un incidente sin atender a tiempo escala (−6 de reputación).

### Eventos de ciudad
Diez situaciones que aparecen en lugares concretos (marcadas con "!" y en el minimapa): USB abandonado, skimmer en el
cajero, Wi-Fi gemelo malvado, vishing, tailgating, QR fraudulento, shoulder surfing, contraseña en post-it, juice
jacking y tarjeta de acceso perdida. Cada decisión da XP y reputación con retroalimentación.

### Progresión
- Energía (baja con el tiempo y al trabajar; < 20 = caminas más lento), dinero y reputación (0 = despido).
- **Carrera**: Analista SOC Junior (N1) → Analista SOC (N2) → Threat Hunter → Líder del SOC → CISO. Cada nivel
  desbloquea categorías, aumenta el número de incidentes y el salario.
- Tras las 17:00: resumen del día; se puede seguir explorando de noche o dormir en casa (salario y nuevo día).
- Guardado automático en `user://` al dormir.

## 4. Arquitectura

```
main.gd (orquestador: reloj, jornada, eventos, ventanas)
├── CityBuilder ─► Buildings / HQ / Props (MultiMesh vía Batcher) ─► CityData (minimapa, marcadores, lugares de eventos)
├── DayNight (WorldEnvironment, sol, luna, cielo, luces nocturnas)
├── Player (CharacterBody3D + SpringArm3D + Person)
├── Traffic (semáforos + AnimatableBody3D) · Pedestrians
├── WorkDay ─► ChallengeBank ─► data/challenges/*.json
├── CityEvents ─► data/city_events.json
└── UiRoot (CanvasLayer, pausa el árbol con ventanas abiertas)
    ├── Hud (+ Minimap)
    └── Dialogs / SocConsole
GameState (autoload: día, hora, dinero, reputación, energía, XP, guardado)
```

- **Data-driven**: añadir un negocio, un tipo de incidente o un evento no requiere tocar la lógica.
- **Rendimiento**: árboles, farolas, bancas y pasos de cebra se agrupan en `MultiMeshInstance3D`.
- **Contenido seguro**: las IP atacantes usan rangos de documentación (RFC 5737) y los dominios son ficticios.
- **Calidad gráfica** ajustable en el menú de pausa (SSAO, glow, distancia de sombras, MSAA).

## 5. Pruebas

- `gdlint scripts`: estilo y errores de sintaxis (gdtoolkit).
- Prueba de humo automática: `godot --headless --path . -- --smoke-test` recorre inicio de partida, generación de
  las 7 categorías, consola SOC, tienda, evento de ciudad, caminar, dormir y menú de pausa; termina con código 0 si todo
  sale bien. Con ventana añade `--shots=<carpeta>` para guardar capturas.

## 6. Hoja de ruta

### Fase 1 — Fundamentos (prototipo web) ✅
### Fase 2 — Proyecto Godot v0.2 ✅
- [x] Ciudad, negocios con interior, sede con SOC, tráfico con semáforos, peatones, día/noche
- [x] 7 categorías de incidentes en JSON, 10 eventos de ciudad, carrera profesional
- [x] HUD, minimapa, consola SOC, tiendas, menús, guardado, calidad gráfica, prueba de humo

### Fase 3 — Arte y mundo
- [ ] Modelos glTF CC0 (Kenney City Kit, Quaternius) y personajes con animaciones (Mixamo) usando `AnimationTree`.
- [ ] Interior de la casa del jugador y pisos superiores de CyberShield (laboratorio forense, sala de crisis).
- [ ] Clima (lluvia amazónica), sonido ambiente y música.
- [ ] Navegación de NPC con `NavigationAgent3D` (entran a los negocios, cruzan calles con el semáforo).

### Fase 4 — Contenido de ciberseguridad
- [ ] Terminal interactiva con comandos simulados (`nmap`, `grep`, `netstat`, `whois`) para retos avanzados.
- [ ] Incidentes encadenados (phishing ignorado → malware → ransomware) y campañas de varios días.
- [ ] Categorías nuevas: DLP / fuga de datos, análisis de PCAP, revisión de código (SQLi, XSS), nube (buckets públicos).
- [ ] Glosario / enciclopedia desbloqueable con mapeo a MITRE ATT&CK.
- [ ] Editor de retos dentro del juego (o importador desde hoja de cálculo) para instructores.

### Fase 5 — Producción
- [ ] Opciones completas (sensibilidad, volumen, idioma ES/EN, reasignar teclas), soporte de mando.
- [ ] Exportación a Windows/Linux/Web y CI que ejecute `gdlint` + prueba de humo en cada cambio.
- [ ] Modo multijugador (compañeros reales en el mismo SOC) con la API de red de Godot.
