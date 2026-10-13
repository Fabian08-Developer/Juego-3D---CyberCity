# CyberCity — Documento de Diseño (GDD) y Hoja de Ruta

## 1. Visión

Un juego 3D, en primera y tercera persona, que combina **exploración urbana** con **simulación profesional de
ciberseguridad**. El jugador vive la rutina de un(a) Ingeniero(a) en Ciberseguridad: llega al trabajo, atiende alertas
reales (basadas en CVE y técnicas MITRE ATT&CK auténticas), gestiona su energía y construye su reputación.

**Pilares**

1. **Realismo educativo** — cada reto enseña algo verdadero (Heartbleed, Log4Shell, BEC, LOLBins, viaje imposible…).
2. **Presión de tiempo con agencia** — las alertas tienen plazos; el jugador decide cuándo salir a la ciudad y cuándo volver.
3. **Una ciudad con vida** — negocios útiles, peatones, tráfico y consejos de seguridad del mundo cotidiano.

**Público**: estudiantes y profesionales de TI, entusiastas de la ciberseguridad, uso en formación/concientización corporativa.

## 2. Decisión tecnológica

| Opción | Ventajas | Desventajas | Veredicto |
| --- | --- | --- | --- |
| **Three.js + TypeScript (web)** | Se juega desde un enlace; UI HTML perfecta para terminales/logs; iteración rapidísima; gratis | Más trabajo propio para física, animación y editor de niveles | ✅ **Elegida para el MVP** |
| Unity (C#) | Editor visual, Asset Store, exporta a PC/móvil/WebGL | Build WebGL pesado; UI de texto denso más incómoda | Buena opción si se busca publicar en Steam/móvil |
| Godot 4 | Libre, ligero, buen editor | Export web aún limitado en 3D; comunidad menor | Alternativa sólida a mediano plazo |
| Unreal Engine 5 | Gráficos de máximo nivel | Curva alta, builds enormes, sobredimensionado para el alcance | No recomendado |

**Estrategia**: la lógica de ciberseguridad (`src/cyber/`) es independiente del motor y data-driven. Si en el futuro se
migra a Unity/Godot, los retos se pueden exportar a JSON y reutilizar sin cambios de diseño.

## 3. Mecánicas actuales (v0.1)

### Movimiento y cámara
- Primera persona y tercera persona (tecla `V`), cámara de hombro con detección de colisión contra paredes.
- Correr, saltar, colisiones con edificios/árboles/vehículos, aceras con escalón.

### Ciudad
- Cuadrícula 3×3 de manzanas: parque central con fuente, sede **CyberShield** al norte, calle comercial alrededor del parque.
- Negocios: MegaMarket (supermercado), Café Byte, Droguería Salud+, Pan del Barrio, Restaurante La Esquina, Banco
  Nacional, Librería Código Abierto, TecnoStore, Ferretería El Tornillo.
- Cada negocio vende productos con efectos (energía, reputación) y ofrece un **tip de seguridad** contextual.
- Tráfico que frena ante el jugador, peatones, farolas, árboles, pasos de cebra, ciclo de sol durante la jornada.

### CyberShield (empresa)
- Planta baja interior: recepción, puestos con compañeros trabajando, racks de servidores, pizarra NIST, muro de
  pantallas del SOC (mapa de amenazas, tráfico, alertas activas en vivo) y la estación de trabajo del jugador.

### Incidentes (consola SOC)

| Categoría | El jugador analiza | Ejemplos de lo que debe detectar |
| --- | --- | --- |
| 🛡️ Vulnerabilidades | Resultado de escaneo (host, puerto, servicio, versión) | Apache 2.4.49, OpenSSL 1.0.1f, Log4j 2.14.1, SMBv1, vsftpd 2.3.4, Redis sin auth |
| 🦠 Malware | Lista de procesos (padre, ruta, firma, CPU, red) | svchost fuera de System32, PowerShell `-enc` desde Word, criptominero, doble extensión |
| 🚨 Intrusión | Logs de autenticación | Fuerza bruta + éxito, cuenta admin creada, logs borrados, viaje imposible |
| 🎣 Phishing | Bandeja de correos reportados | Homógrafos, subdominios engañosos, fraude del CEO, adjuntos con macros |

Flujo: **marcar elementos → elegir respuesta → revisión con explicación**. Puntaje = 70 % clasificación + 30 % respuesta.
Pago y reputación escalan con la severidad (Baja ×0.8 … Crítica ×1.5). Los incidentes no atendidos a tiempo escalan (−6 ⭐).

### Progresión
- Energía (baja con el tiempo y al resolver incidentes; <20 = caminas más lento).
- Dinero (pago por incidente + salario diario) y reputación (0 = despido).
- Cada día llegan más incidentes. Guardado automático al terminar el día.

## 4. Hoja de ruta

### Fase 1 — Fundamentos (✅ este prototipo)
- [x] Proyecto Vite + TypeScript + Three.js
- [x] Ciudad procedural, negocios, sede con interior
- [x] Controlador 1ª/3ª persona con colisiones
- [x] Sistema de jornada, 4 categorías de incidentes con generación aleatoria
- [x] HUD, minimapa, consola SOC, tiendas, resumen diario, guardado

### Fase 2 — Contenido de ciberseguridad
- [ ] Nuevas categorías: ransomware (respuesta y recuperación desde backups), DDoS, fuga de datos (DLP), ingeniería social
  presencial (alguien intenta entrar sin tarjeta), configuración de firewall, revisión de código (SQLi/XSS), análisis de PCAP.
- [ ] Mini-terminal interactiva (comandos tipo `nmap`, `grep`, `netstat`) para retos avanzados.
- [ ] Incidentes encadenados (un phishing ignorado → malware → intrusión).
- [ ] Mapeo explícito a MITRE ATT&CK y glosario/enciclopedia desbloqueable.
- [ ] Niveles de carrera: Analista N1 → N2 → Threat Hunter → CISO, con certificaciones (libros/cursos en la ciudad).

### Fase 3 — Mundo y arte
- [ ] Reemplazar geometría procedural por modelos **glTF** (Kenney / Quaternius, licencia CC0) y personajes rigged
  (Mixamo) con animaciones de caminar/correr/teclear.
- [ ] Interiores visitables de los negocios y NPC con diálogos.
- [ ] Ciclo día/noche completo con iluminación nocturna, clima.
- [ ] Física con **Rapier** (`@dimforge/rapier3d-compat`) y semáforos/IA de tráfico.
- [ ] Audio ambiental y efectos (Howler.js).

### Fase 4 — Producción
- [ ] Menú de opciones (calidad gráfica, sensibilidad, idioma ES/EN).
- [ ] Soporte de mando y controles táctiles.
- [ ] Tests unitarios de la lógica de retos (Vitest) y pruebas E2E (Playwright).
- [ ] CI en GitHub Actions + despliegue en GitHub Pages / Netlify.
- [ ] Telemetría opcional de aprendizaje (qué conceptos fallan más los jugadores).

## 5. Arquitectura

```
Game (orquestador) ──► World (escena, colisiones, interactuables, updaters)
   │                      ├── City → Buildings / HQ / Props (instanciados)
   │                      └── Life → tráfico y peatones
   ├── Player (movimiento + cámaras)
   ├── GameState (hora, energía, dinero, reputación, guardado)
   ├── WorkDay (agenda de incidentes, plazos, recompensas)
   │      └── generators → Challenge (datos puros, independientes del motor)
   └── UI: HUD, Minimap, Modal → SocConsole / Shop / DaySummary
```

- **Data-driven**: añadir un negocio = una entrada en `src/data/businesses.ts`; añadir un tipo de incidente = un
  generador que devuelva un `Challenge`.
- **Rendimiento**: los props repetidos se agrupan en `InstancedMesh` (`world/Instancer.ts`).
- **Seguridad del contenido**: las IP atacantes usan rangos de documentación (RFC 5737) y los dominios son ficticios.
