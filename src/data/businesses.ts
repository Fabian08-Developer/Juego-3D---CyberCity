export interface ShopItem {
  name: string;
  price: number;
  description: string;
  energy?: number;
  reputation?: number;
}

export interface BusinessDef {
  id: string;
  name: string;
  type: string;
  wall: string;
  accent: string;
  signText: string;
  height: number;
  greeting: string;
  items: ShopItem[];
  /** Consejo de ciberseguridad relacionado con el negocio (aprendizaje contextual). */
  tip?: string;
}

export const BUSINESSES: BusinessDef[] = [
  {
    id: 'supermercado',
    name: 'MegaMarket',
    type: 'Supermercado',
    wall: '#d9d4c7',
    accent: '#2e9e4f',
    signText: 'MegaMarket · Supermercado',
    height: 8,
    greeting: 'Todo lo que necesitas para tu jornada.',
    items: [
      { name: 'Sándwich', price: 6, energy: 30, description: 'Un almuerzo rápido.' },
      { name: 'Fruta', price: 2, energy: 10, description: 'Ligero y saludable.' },
      { name: 'Bebida energética', price: 5, energy: 35, description: 'Mucha energía… con moderación.' },
    ],
    tip: 'Al pagar con tarjeta, revisa que el datáfono no tenga dispositivos extraños (skimmers).',
  },
  {
    id: 'cafeteria',
    name: 'Café Byte',
    type: 'Cafetería',
    wall: '#8a5a3b',
    accent: '#c8873a',
    signText: '☕ Café Byte',
    height: 7,
    greeting: '¡El combustible oficial de los analistas SOC!',
    items: [
      { name: 'Café americano', price: 3, energy: 20, description: 'Clásico y efectivo.' },
      { name: 'Capuchino', price: 4, energy: 25, description: 'Con espuma de leche.' },
      { name: 'Brownie', price: 3, energy: 12, description: 'Para el antojo.' },
    ],
    tip: 'Evita conectarte al Wi-Fi abierto de la cafetería sin VPN: alguien podría interceptar tu tráfico.',
  },
  {
    id: 'drogueria',
    name: 'Droguería Salud+',
    type: 'Droguería',
    wall: '#e8eef2',
    accent: '#1d8fd1',
    signText: '✚ Droguería Salud+',
    height: 7,
    greeting: 'Cuidamos de ti.',
    items: [
      { name: 'Analgésico', price: 4, energy: 15, description: 'Para el dolor de cabeza tras un incidente crítico.' },
      { name: 'Vitaminas', price: 8, energy: 22, description: 'Un empujón para el resto del día.' },
    ],
    tip: 'Los datos de salud son información sensible: nunca los envíes por canales no cifrados.',
  },
  {
    id: 'panaderia',
    name: 'Pan del Barrio',
    type: 'Panadería',
    wall: '#f0d9a8',
    accent: '#b5651d',
    signText: '🥖 Pan del Barrio',
    height: 7,
    greeting: 'Pan recién horneado todo el día.',
    items: [
      { name: 'Pan de bono', price: 2, energy: 10, description: 'Calientito.' },
      { name: 'Croissant', price: 3, energy: 14, description: 'De mantequilla.' },
    ],
  },
  {
    id: 'restaurante',
    name: 'La Esquina',
    type: 'Restaurante',
    wall: '#a8443b',
    accent: '#f2b134',
    signText: '🍽 Restaurante La Esquina',
    height: 9,
    greeting: 'Almuerzo ejecutivo del día.',
    items: [{ name: 'Almuerzo ejecutivo', price: 12, energy: 50, description: 'Sopa, plato fuerte y jugo.' }],
  },
  {
    id: 'banco',
    name: 'Banco Nacional',
    type: 'Banco',
    wall: '#cfd6dd',
    accent: '#1f3a68',
    signText: '🏦 Banco Nacional',
    height: 14,
    greeting: 'Tu dinero, seguro.',
    items: [],
    tip: 'Ningún banco te pedirá tu contraseña o código OTP por correo, SMS o llamada. Si ocurre: es phishing.',
  },
  {
    id: 'libreria',
    name: 'Código Abierto',
    type: 'Librería',
    wall: '#5b6b8c',
    accent: '#7c5cff',
    signText: '📚 Librería Código Abierto',
    height: 8,
    greeting: 'Libros técnicos y de ciencia ficción.',
    items: [
      { name: 'Libro: Hacking Ético', price: 25, reputation: 3, description: 'Estudiar mejora tu reputación profesional.' },
      { name: 'Guía de respuesta a incidentes', price: 30, reputation: 4, description: 'Basada en NIST SP 800-61.' },
    ],
  },
  {
    id: 'tecnostore',
    name: 'TecnoStore',
    type: 'Tienda de tecnología',
    wall: '#2b2f3a',
    accent: '#00c2a8',
    signText: '💻 TecnoStore',
    height: 10,
    greeting: 'Gadgets y hardware.',
    items: [
      { name: 'Llave de seguridad FIDO2', price: 45, reputation: 5, description: 'MFA resistente a phishing.' },
      { name: 'Cable USB "de regalo"', price: 0, reputation: -3, description: 'Nunca conectes dispositivos USB de origen desconocido…' },
    ],
  },
  {
    id: 'ferreteria',
    name: 'El Tornillo',
    type: 'Ferretería',
    wall: '#c9b48a',
    accent: '#e05a2b',
    signText: '🔧 Ferretería El Tornillo',
    height: 7,
    greeting: 'Herramientas para todo.',
    items: [{ name: 'Tapa para webcam', price: 1, reputation: 1, description: 'Privacidad ante todo.' }],
    tip: 'La seguridad física también importa: un candado débil en el rack anula el mejor firewall.',
  },
];
