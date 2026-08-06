import type { ImageFormat } from './constants';

// ─── Formata tamanho de arquivo ─────────────────────────────────────────────
export function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  const value = bytes / Math.pow(1024, i);
  return `${value.toFixed(i === 0 ? 0 : 1)} ${units[i]}`;
}

// ─── Remove extensão do nome de arquivo ─────────────────────────────────────
export function stripExtension(filename: string): string {
  return filename.replace(/\.[^/.]+$/, '');
}

// ─── Retorna extensão de arquivo ─────────────────────────────────────────────
export function getFileExtension(filename: string): string {
  const parts = filename.split('.');
  return parts.length > 1 ? parts[parts.length - 1].toLowerCase() : '';
}

// ─── Gera nome sugerido para o download ─────────────────────────────────────
export function suggestFilename(originalName: string, format: ImageFormat): string {
  const base = stripExtension(originalName);
  const extMap: Record<ImageFormat, string> = {
    png: 'png',
    jpeg: 'jpg',
    webp: 'webp',
    gif: 'gif',
    svg: 'svg',
  };
  return `${base}_convertido.${extMap[format]}`;
}

// ─── Calcula redução percentual ──────────────────────────────────────────────
export function calcSizeReduction(original: number, converted: number): number {
  if (original === 0) return 0;
  return Math.round(((original - converted) / original) * 100);
}

// ─── Verifica se o arquivo é uma imagem ─────────────────────────────────────
export function isImageFile(file: File): boolean {
  return file.type.startsWith('image/');
}

// ─── Retorna MIME type para formato ─────────────────────────────────────────
export function getMimeType(format: ImageFormat): string {
  const map: Record<ImageFormat, string> = {
    png: 'image/png',
    jpeg: 'image/jpeg',
    webp: 'image/webp',
    gif: 'image/gif',
    svg: 'image/svg+xml',
  };
  return map[format];
}

// ─── Formata tempo em ms ─────────────────────────────────────────────────────
export function formatTime(ms: number): string {
  if (ms < 1000) return `${ms}ms`;
  return `${(ms / 1000).toFixed(1)}s`;
}
