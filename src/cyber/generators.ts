import { pick, randInt, sample, shuffle } from '../core/random';
import { ActionOption, Category, Challenge, ChallengeRow, Severity } from './types';

/*
 * Generadores de retos. Los datos son realistas (CVE reales, técnicas MITRE
 * ATT&CK comunes) pero las IP de atacantes usan rangos de documentación
 * (RFC 5737) y los dominios son ficticios.
 */

const DOMAIN = 'cybershield.lat';
const EMPLOYEES = ['ana.gomez', 'carlos.ruiz', 'laura.mendez', 'diego.torres', 'sofia.rios', 'andres.vega', 'valentina.paz'];
const attackerIP = () => `${pick(['203.0.113', '198.51.100', '192.0.2'])}.${randInt(2, 254)}`;
const internalIP = () => `10.20.${randInt(1, 30)}.${randInt(2, 250)}`;
const time = (h: number, m: number) => `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;

function action(question: string, correct: Omit<ActionOption, 'correct'>, wrong: Omit<ActionOption, 'correct'>[]): Challenge['action'] {
  return {
    question,
    options: shuffle([{ ...correct, correct: true }, ...sample(wrong, 3).map((w) => ({ ...w, correct: false }))]),
  };
}

function mix(bad: ChallengeRow[], good: ChallengeRow[], nBad: number, nGood: number): ChallengeRow[] {
  return shuffle([...sample(bad, nBad), ...sample(good, nGood)]);
}

// ---------------------------------------------------------------- Vulnerabilidades
type Svc = [port: string, service: string, version: string, explanation: string];
const VULN_BAD: Svc[] = [
  ['80/tcp', 'HTTP (Apache httpd)', '2.4.49', 'Apache 2.4.49 es vulnerable a CVE-2021-41773 (path traversal y posible RCE). Actualizar a ≥ 2.4.51.'],
  ['443/tcp', 'HTTPS (OpenSSL)', 'OpenSSL 1.0.1f', 'OpenSSL 1.0.1f es vulnerable a Heartbleed (CVE-2014-0160): fuga de memoria del servidor, incluidas claves privadas.'],
  ['8080/tcp', 'App Java (Log4j)', 'log4j-core 2.14.1', 'Log4j 2.14.1 es vulnerable a Log4Shell (CVE-2021-44228): ejecución remota vía JNDI. Actualizar a ≥ 2.17.1.'],
  ['445/tcp', 'SMB', 'SMBv1 · Windows Server 2008 R2', 'SMBv1 sin el parche MS17-010 es explotable con EternalBlue (usado por WannaCry). Deshabilitar SMBv1 y parchear.'],
  ['21/tcp', 'FTP (vsftpd)', '2.3.4', 'vsftpd 2.3.4 contiene una puerta trasera conocida (CVE-2011-2523) que abre una shell en el puerto 6200.'],
  ['23/tcp', 'Telnet', 'telnetd', 'Telnet envía credenciales en texto plano. Reemplazar por SSH.'],
  ['3389/tcp', 'RDP', 'Windows 7 · sin NLA', 'RDP expuesto sin NLA en Windows 7 es vulnerable a BlueKeep (CVE-2019-0708). No exponer RDP; usar VPN.'],
  ['6379/tcp', 'Redis', '5.0 · sin autenticación', 'Redis expuesto sin autenticación permite leer/escribir datos y a menudo ejecutar código.'],
  ['3306/tcp', 'MySQL', '5.7 · root sin contraseña', 'Base de datos accesible desde la red con root sin contraseña. Credenciales fuertes y acceso restringido.'],
  ['9200/tcp', 'Elasticsearch', '6.8 · acceso anónimo', 'Elasticsearch sin autenticación expone todos los índices. Habilitar seguridad y restringir red.'],
];
const VULN_GOOD: Svc[] = [
  ['22/tcp', 'SSH (OpenSSH)', '9.8p1 · solo llaves', 'OpenSSH actualizado con autenticación por llave pública: configuración correcta.'],
  ['443/tcp', 'HTTPS (nginx)', '1.26.2 · TLS 1.3', 'nginx actualizado con TLS 1.3: sin vulnerabilidades conocidas relevantes.'],
  ['5432/tcp', 'PostgreSQL', '16.4 · solo red interna', 'Versión soportada y accesible únicamente desde la red interna.'],
  ['53/udp', 'DNS (BIND)', '9.18 · recursión deshabilitada', 'Versión soportada; sin recursión abierta no puede usarse para amplificación.'],
  ['443/tcp', 'HTTPS (Apache httpd)', '2.4.62', 'Apache 2.4.62 ya incluye los parches de CVE-2021-41773/42013.'],
  ['587/tcp', 'SMTP (Postfix)', '3.8 · STARTTLS + auth', 'Envío autenticado y cifrado: configuración correcta.'],
  ['636/tcp', 'LDAPS', 'Active Directory · TLS', 'LDAP sobre TLS: las credenciales viajan cifradas.'],
];
const HOSTS = ['web-01', 'web-02', 'db-prod', 'ftp-legacy', 'app-erp', 'dc-01', 'mail-01', 'cache-01', 'logs-01', 'vpn-gw'];

function vulnChallenge(severity: Severity): Challenge {
  const hosts = shuffle([...HOSTS]);
  const toRow = (s: Svc, bad: boolean, i: number): ChallengeRow => ({
    cells: [hosts[i % hosts.length], internalIP(), s[0], s[1], s[2]],
    bad,
    explanation: s[3],
  });
  const nBad = randInt(2, 3);
  const rows = shuffle([...sample(VULN_BAD, nBad).map((s) => [s, true] as const), ...sample(VULN_GOOD, 6 - nBad).map((s) => [s, false] as const)])
    .map(([s, bad], i) => toRow(s, bad, i));
  return {
    category: 'vuln',
    title: 'Escaneo trimestral de vulnerabilidades',
    severity,
    briefing: 'El escáner (tipo Nmap/OpenVAS) terminó de revisar el segmento de servidores. Revisa los servicios detectados.',
    instruction: 'Marca los servicios VULNERABLES o mal configurados.',
    columns: ['Host', 'IP', 'Puerto', 'Servicio', 'Versión / Configuración'],
    rows,
    action: action(
      'Con los hallazgos confirmados, ¿cuál es el siguiente paso?',
      { text: 'Priorizar por criticidad (CVSS) y exposición, aplicar parches o mitigaciones y verificar con un nuevo escaneo.', feedback: 'Correcto: gestión de vulnerabilidades basada en riesgo y verificación del cierre.' },
      [
        { text: 'Apagar todos los servidores de la empresa hasta nuevo aviso.', feedback: 'Desproporcionado: detiene el negocio. Se debe priorizar y mitigar.' },
        { text: 'Ignorar los hallazgos: el firewall perimetral ya nos protege.', feedback: 'Defensa en profundidad: el firewall no corrige servicios vulnerables internos.' },
        { text: 'Publicar el informe en redes sociales para alertar al público.', feedback: 'Divulgar vulnerabilidades sin corregir facilita el ataque.' },
        { text: 'Esperar a la próxima auditoría anual para corregirlos.', feedback: 'Las vulnerabilidades críticas deben corregirse según SLA, no meses después.' },
      ],
    ),
  };
}

// ---------------------------------------------------------------- Malware
type Proc = [name: string, parent: string, path: string, signer: string, cpu: string, net: string, explanation: string];
const MAL_BAD = (user: string): Proc[] => [
  ['svchost.exe', 'explorer.exe', 'C:\\Users\\Public\\svchost.exe', 'Sin firma', '3%', `${attackerIP()}:4444`, 'svchost.exe legítimo solo corre desde C:\\Windows\\System32 y lo lanza services.exe. Ruta anómala + sin firma + puerto 4444 = malware que suplanta un proceso del sistema.'],
  ['powershell.exe -w hidden -enc JABzAD0A…', 'WINWORD.EXE', 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\', 'Microsoft', '12%', `${attackerIP()}:443`, 'PowerShell oculto con comando codificado en Base64 lanzado por Word: patrón típico de macro maliciosa (T1059.001).'],
  ['sysupdate.exe', 'services.exe', 'C:\\ProgramData\\sysupdate\\sysupdate.exe', 'Sin firma', '97%', `${attackerIP()}:3333`, 'CPU cercana al 100% sostenida y conexión al puerto 3333 (protocolo Stratum): criptominero.'],
  ['factura_2026.pdf.exe', 'explorer.exe', `C:\\Users\\${user}\\Downloads\\`, 'Sin firma', '1%', `${attackerIP()}:8080`, 'Doble extensión (.pdf.exe): un ejecutable disfrazado de documento.'],
  ['rundll32.exe upd.dll,Start', 'explorer.exe', 'C:\\ProgramData\\upd.dll', 'Sin firma', '2%', `${attackerIP()}:443`, 'rundll32 cargando una DLL sin firma desde ProgramData con conexión saliente: técnica común de loaders (T1218.011).'],
  ['mshta.exe http://…/a.hta', 'OUTLOOK.EXE', 'C:\\Windows\\System32\\mshta.exe', 'Microsoft', '1%', `${attackerIP()}:80`, 'mshta ejecutando un HTA remoto abierto desde Outlook: ejecución de código vía binario del sistema (T1218.005).'],
];
const MAL_GOOD = (user: string): Proc[] => [
  ['explorer.exe', 'userinit.exe', 'C:\\Windows\\explorer.exe', 'Microsoft', '1%', '—', 'Shell de Windows, ruta y firma correctas.'],
  ['chrome.exe', 'explorer.exe', 'C:\\Program Files\\Google\\Chrome\\Application\\', 'Google LLC', '4%', 'www.google.com:443', 'Navegador firmado en su ruta oficial.'],
  ['svchost.exe -k netsvcs', 'services.exe', 'C:\\Windows\\System32\\svchost.exe', 'Microsoft', '0.5%', '—', 'svchost legítimo: ruta System32, padre services.exe y firmado por Microsoft.'],
  ['MsMpEng.exe', 'services.exe', 'C:\\ProgramData\\Microsoft\\Windows Defender\\Platform\\', 'Microsoft', '6%', '—', 'Motor antimalware de Microsoft Defender.'],
  ['ms-teams.exe', 'explorer.exe', 'C:\\Program Files\\WindowsApps\\MSTeams\\', 'Microsoft', '3%', 'teams.microsoft.com:443', 'Cliente de Teams firmado conectando a su servicio oficial.'],
  ['OneDrive.exe', 'explorer.exe', `C:\\Users\\${user}\\AppData\\Local\\Microsoft\\OneDrive\\`, 'Microsoft', '1%', 'onedrive.live.com:443', 'Sincronización de OneDrive en su ruta habitual por usuario.'],
  ['lsass.exe', 'wininit.exe', 'C:\\Windows\\System32\\lsass.exe', 'Microsoft', '0.2%', '—', 'Proceso de autenticación legítimo (ruta y padre correctos).'],
];

function malwareChallenge(severity: Severity): Challenge {
  const user = pick(EMPLOYEES);
  const rows = mix(
    MAL_BAD(user).map(([...c]) => ({ cells: c.slice(0, 6), bad: true, explanation: c[6] })),
    MAL_GOOD(user).map(([...c]) => ({ cells: c.slice(0, 6), bad: false, explanation: c[6] })),
    randInt(1, 2),
    5,
  );
  return {
    category: 'malware',
    title: `Comportamiento anómalo en el equipo de ${user}`,
    severity,
    briefing: `El EDR reporta actividad sospechosa en WS-${randInt(100, 499)} (${user}). Tienes la lista de procesos activos.`,
    instruction: 'Marca los procesos MALICIOSOS.',
    columns: ['Proceso', 'Proceso padre', 'Ruta', 'Firma', 'CPU', 'Conexión'],
    rows,
    action: action(
      'Confirmaste malware en el equipo. ¿Qué haces primero?',
      { text: 'Aislar el equipo de la red con el EDR, preservar evidencia (memoria y disco) y luego erradicar y restaurar.', feedback: 'Correcto: contener primero sin destruir evidencia.' },
      [
        { text: 'Reiniciar el equipo para que el proceso desaparezca.', feedback: 'Se pierde la evidencia en memoria y el malware puede tener persistencia.' },
        { text: 'Formatear inmediatamente sin recolectar evidencia.', feedback: 'Sin evidencia no sabrás cómo entró ni si se propagó.' },
        { text: 'Pedirle al usuario que borre el archivo y siga trabajando.', feedback: 'El equipo sigue comprometido y conectado a la red.' },
        { text: 'Pagar al atacante para que se vaya.', feedback: 'Nunca: no garantiza nada y financia al crimen.' },
      ],
    ),
  };
}

// ---------------------------------------------------------------- Intrusión
function intrusionChallenge(severity: Severity): Challenge {
  const ip = attackerIP();
  const victim = pick(['admin', 'svc_backup', pick(EMPLOYEES)]);
  const traveler = pick(EMPLOYEES.filter((e) => e !== victim));
  const h = randInt(1, 4);
  const bad: ChallengeRow[] = [
    { cells: [time(h, 2), ip, victim, '412 inicios de sesión fallidos en 3 min', 'Exterior (VPS)'], bad: true, explanation: 'Cientos de fallos en minutos desde una IP externa: ataque de fuerza bruta (T1110).' },
    { cells: [time(h, 5), ip, victim, 'Inicio de sesión EXITOSO (SSH)', 'Exterior (VPS)'], bad: true, explanation: 'Éxito justo después de la fuerza bruta desde la misma IP: la cuenta está comprometida.' },
    { cells: [time(h, 9), ip, victim, "Usuario 'soporte_tmp' creado y añadido a Administradores", 'Exterior (VPS)'], bad: true, explanation: 'Crear cuentas privilegiadas es una técnica de persistencia (T1136).' },
    { cells: [time(h, 14), ip, victim, 'Registro de seguridad borrado (Event ID 1102)', 'Exterior (VPS)'], bad: true, explanation: 'Borrar logs es una técnica anti-forense para ocultar el rastro (T1070).' },
    { cells: [time(8, 15), attackerIP(), traveler, 'Inicio de sesión exitoso (VPN)', 'Otro continente'], bad: true, explanation: `"Viaje imposible": ${traveler} inició sesión desde la oficina minutos antes. Probable robo de credenciales.` },
  ];
  const good: ChallengeRow[] = [
    { cells: [time(8, 1), internalIP(), pick(EMPLOYEES), 'Inicio de sesión exitoso', 'Oficina principal'], bad: false, explanation: 'Inicio de sesión normal en horario laboral desde la red interna.' },
    { cells: [time(8, 7), internalIP(), traveler, 'Inicio de sesión exitoso', 'Oficina principal'], bad: false, explanation: 'Acceso legítimo desde la oficina.' },
    { cells: [time(8, 20), internalIP(), pick(EMPLOYEES), '1 intento fallido y luego éxito', 'Oficina principal'], bad: false, explanation: 'Un error aislado al escribir la contraseña es normal.' },
    { cells: [time(8, 31), internalIP(), pick(EMPLOYEES), 'Cambio de contraseña (política de 90 días)', 'Oficina principal'], bad: false, explanation: 'Cambio de contraseña programado por la política.' },
    { cells: [time(8, 45), internalIP(), pick(EMPLOYEES), 'Cierre de sesión', 'Oficina principal'], bad: false, explanation: 'Evento rutinario.' },
  ];
  const rows = [...sample(bad.slice(0, 2), 2), ...sample(bad.slice(2), randInt(1, 2)), good[1], ...sample([good[0], ...good.slice(2)], 3)].sort((a, b) => a.cells[0].localeCompare(b.cells[0]));
  return {
    category: 'intrusion',
    title: `Accesos sospechosos a la cuenta ${victim}`,
    severity,
    briefing: 'El SIEM correlacionó eventos de autenticación inusuales en la última noche. Revisa el registro.',
    instruction: 'Marca los eventos que evidencian una INTRUSIÓN.',
    columns: ['Hora', 'IP origen', 'Usuario', 'Evento', 'Ubicación'],
    rows,
    action: action(
      '¿Cuál es la respuesta adecuada?',
      { text: 'Bloquear la IP, deshabilitar y restablecer las cuentas comprometidas, revocar sesiones activas y buscar movimiento lateral.', feedback: 'Correcto: contención completa y búsqueda del alcance.' },
      [
        { text: 'Solo bloquear la IP; la contraseña robada ya no importa.', feedback: 'El atacante puede volver desde otra IP con la credencial válida.' },
        { text: 'Observar en silencio qué más hace el intruso sin avisar a nadie.', feedback: 'Sin contención el daño crece; cualquier monitoreo debe ser coordinado y autorizado.' },
        { text: 'Eliminar los registros para que no quede rastro del incidente.', feedback: 'Destruye evidencia y puede incumplir obligaciones legales.' },
        { text: 'Cambiar solo tu propia contraseña por precaución.', feedback: 'No afecta las cuentas comprometidas.' },
      ],
    ),
  };
}

// ---------------------------------------------------------------- Phishing
type Mail = [from: string, subject: string, link: string, explanation: string];
const PHISH_BAD: Mail[] = [
  ['soporte@micros0ft-seguridad.com', '⚠ Su cuenta será suspendida en 24 h', 'http://micros0ft-login.xyz/verify', 'Dominio con "0" en lugar de "o", urgencia artificial y enlace HTTP a un dominio externo.'],
  [`rrhh@cybershie1d.lat`, 'Actualización de nómina – acción requerida', 'nomina_octubre.xlsm', 'Dominio suplantado ("1" en lugar de "l") y adjunto de Excel con macros.'],
  ['ceo.cybershield@gmail.com', 'Transferencia urgente y confidencial', '(sin enlace) — pide transferir $25.000', 'Fraude del CEO (BEC): cuenta gratuita, urgencia y petición de dinero fuera de proceso.'],
  ['notificaciones@dhl-entregas.top', 'Su paquete está retenido', 'https://bit.ly/3xP4qT', 'Dominio no oficial y acortador de URL que oculta el destino real.'],
  [`it-helpdesk@${DOMAIN}.reset-pass.co`, 'Restablezca su contraseña hoy', `https://${DOMAIN}.reset-pass.co/login`, `El dominio real es reset-pass.co; "${DOMAIN}" es solo un subdominio engañoso.`],
  ['facturacion@proveedor-pagos.example', 'Factura vencida #88231', 'factura.pdf.js', 'Archivo JavaScript disfrazado de PDF: al abrirlo ejecuta código.'],
];
const PHISH_GOOD: Mail[] = [
  [`it@${DOMAIN}`, 'Mantenimiento programado de la VPN (sábado 22:00)', `https://intranet.${DOMAIN}/avisos`, 'Remitente y enlace del dominio corporativo legítimo, sin urgencia ni pedidos de datos.'],
  ['noreply@github.com', '[GitHub] Revisión solicitada en el PR #142', 'https://github.com/cybershield/portal/pull/142', 'Notificación legítima de GitHub a su dominio oficial.'],
  [`laura.mendez@${DOMAIN}`, 'Agenda de la reunión de equipo', 'invitacion.ics', 'Invitación de calendario de una compañera, archivo .ics normal.'],
  [`seguridad@${DOMAIN}`, 'Recordatorio: capacitación anual de seguridad', `https://campus.${DOMAIN}`, 'Comunicado interno con enlace al dominio corporativo.'],
  [`nomina@${DOMAIN}`, 'Tu desprendible de pago está disponible', `https://portal.${DOMAIN}/nomina`, 'Remitente y portal corporativos; no pide credenciales por correo.'],
];

function phishingChallenge(severity: Severity): Challenge {
  const toRow = (m: Mail, bad: boolean): ChallengeRow => ({ cells: m.slice(0, 3), bad, explanation: m[3] });
  const rows = mix(PHISH_BAD.map((m) => toRow(m, true)), PHISH_GOOD.map((m) => toRow(m, false)), randInt(2, 3), 3);
  return {
    category: 'phishing',
    title: 'Correos reportados por los empleados',
    severity,
    briefing: 'Varios empleados usaron el botón "Reportar phishing". Analiza los correos en la bandeja de cuarentena.',
    instruction: 'Marca los correos de PHISHING.',
    columns: ['Remitente', 'Asunto', 'Enlace / Adjunto'],
    rows,
    action: action(
      'Confirmaste una campaña de phishing. ¿Qué haces?',
      { text: 'Retirar los correos de todos los buzones, bloquear remitentes/dominios, alertar a los usuarios y verificar quién hizo clic.', feedback: 'Correcto: contención, prevención y búsqueda de víctimas.' },
      [
        { text: 'Responder al remitente pidiendo que deje de escribir.', feedback: 'Confirma que el buzón está activo y no protege a nadie.' },
        { text: 'Abrir el enlace desde tu equipo para comprobar si es malicioso.', feedback: 'Se analiza en un sandbox aislado, nunca en tu equipo de trabajo.' },
        { text: 'Reenviar el correo a toda la empresa para que lo vean.', feedback: 'Distribuye el enlace malicioso a más personas.' },
        { text: 'No hacer nada: los usuarios ya lo reportaron.', feedback: 'Otros empleados pudieron recibirlo y hacer clic.' },
      ],
    ),
  };
}

const SEVERITIES: Record<Category, Severity[]> = {
  vuln: ['Media', 'Alta', 'Alta', 'Crítica'],
  malware: ['Alta', 'Alta', 'Crítica'],
  intrusion: ['Alta', 'Crítica', 'Crítica'],
  phishing: ['Baja', 'Media', 'Media', 'Alta'],
};

const GENERATORS: Record<Category, (s: Severity) => Challenge> = {
  vuln: vulnChallenge,
  malware: malwareChallenge,
  intrusion: intrusionChallenge,
  phishing: phishingChallenge,
};

export function generateChallenge(category: Category): Challenge {
  return GENERATORS[category](pick(SEVERITIES[category]));
}

export const ALL_CATEGORIES = Object.keys(GENERATORS) as Category[];
