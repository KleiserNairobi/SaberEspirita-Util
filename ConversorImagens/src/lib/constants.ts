// ─── Formatos Suportados ────────────────────────────────────────────────────
export type ImageFormat = 'png' | 'jpeg' | 'webp' | 'gif' | 'svg';

export interface FormatInfo {
  id: ImageFormat;
  label: string;
  extension: string;
  mimeType: string;
  description: string;
  supportsQuality: boolean;
  supportsTransparency: boolean;
  color: string;
  emoji: string;
}

export const SUPPORTED_FORMATS: FormatInfo[] = [
  {
    id: 'png',
    label: 'PNG',
    extension: 'png',
    mimeType: 'image/png',
    description: 'Sem perda, com transparência',
    supportsQuality: false,
    supportsTransparency: true,
    color: '#4a90d9',
    emoji: '🖼️',
  },
  {
    id: 'jpeg',
    label: 'JPEG',
    extension: 'jpg',
    mimeType: 'image/jpeg',
    description: 'Comprimido, para fotos',
    supportsQuality: true,
    supportsTransparency: false,
    color: '#e8854a',
    emoji: '📸',
  },
  {
    id: 'webp',
    label: 'WebP',
    extension: 'webp',
    mimeType: 'image/webp',
    description: 'Moderno, menor tamanho',
    supportsQuality: true,
    supportsTransparency: true,
    color: '#6f7c60',
    emoji: '🌐',
  },
  {
    id: 'gif',
    label: 'GIF',
    extension: 'gif',
    mimeType: 'image/gif',
    description: 'Animações e gráficos',
    supportsQuality: false,
    supportsTransparency: true,
    color: '#a970c4',
    emoji: '🎞️',
  },
  {
    id: 'svg',
    label: 'SVG',
    extension: 'svg',
    mimeType: 'image/svg+xml',
    description: 'Vetorial, escalável',
    supportsQuality: false,
    supportsTransparency: true,
    color: '#e84a7a',
    emoji: '✏️',
  },
];

// ─── Limites de Validação ───────────────────────────────────────────────────
export const VALIDATION_LIMITS = {
  maxFileSizeMB: 50,
  maxFileSizeBytes: 50 * 1024 * 1024,
  maxDimension: 16000,
  minDimension: 1,
} as const;

// ─── Qualidade padrão ───────────────────────────────────────────────────────
export const DEFAULT_QUALITY = 85;

// ─── Tipos de arquivo aceitos pelo input ────────────────────────────────────
export const ACCEPTED_MIME_TYPES = [
  'image/png',
  'image/jpeg',
  'image/webp',
  'image/gif',
  'image/svg+xml',
  'image/bmp',
  'image/tiff',
].join(',');
