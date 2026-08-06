import type { ImageFormat } from './constants';
import { getMimeType } from './formatUtils';

// ─── Tipos ───────────────────────────────────────────────────────────────────
export interface ConversionResult {
  blob: Blob;
  url: string;
  width: number;
  height: number;
  sizeBytes: number;
  durationMs: number;
}

// ─── Carrega imagem a partir de um File ──────────────────────────────────────
function loadImage(file: File): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      URL.revokeObjectURL(url);
      resolve(img);
    };
    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error('Não foi possível carregar a imagem.'));
    };
    img.src = url;
  });
}

// ─── Carrega SVG a partir de um File ────────────────────────────────────────
async function loadSvgAsImage(file: File, targetWidth?: number, targetHeight?: number): Promise<HTMLImageElement> {
  const text = await file.text();
  const parser = new DOMParser();
  const doc = parser.parseFromString(text, 'image/svg+xml');
  const svgEl = doc.documentElement;

  // Garante viewBox e dimensões
  const vb = svgEl.getAttribute('viewBox');
  const w = svgEl.getAttribute('width');
  const h = svgEl.getAttribute('height');

  if (!w || !h) {
    if (vb) {
      const parts = vb.split(/[\s,]+/);
      svgEl.setAttribute('width', parts[2] ?? '800');
      svgEl.setAttribute('height', parts[3] ?? '600');
    } else {
      svgEl.setAttribute('width', String(targetWidth ?? 800));
      svgEl.setAttribute('height', String(targetHeight ?? 600));
    }
  }

  const serialized = new XMLSerializer().serializeToString(svgEl);
  const blob = new Blob([serialized], { type: 'image/svg+xml;charset=utf-8' });
  const url = URL.createObjectURL(blob);

  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => { URL.revokeObjectURL(url); resolve(img); };
    img.onerror = () => { URL.revokeObjectURL(url); reject(new Error('Erro ao renderizar SVG.')); };
    img.src = url;
  });
}

// ─── Desenha imagem em canvas e exporta como Blob ───────────────────────────
function imageToBlob(img: HTMLImageElement, mimeType: string, quality: number): Promise<Blob> {
  return new Promise((resolve, reject) => {
    const canvas = document.createElement('canvas');
    canvas.width = img.naturalWidth || img.width;
    canvas.height = img.naturalHeight || img.height;
    const ctx = canvas.getContext('2d');
    if (!ctx) { reject(new Error('Canvas não suportado.')); return; }

    // Fundo branco para formatos sem transparência (JPEG)
    if (mimeType === 'image/jpeg') {
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
    }

    ctx.drawImage(img, 0, 0);
    canvas.toBlob(
      (blob) => {
        if (blob) resolve(blob);
        else reject(new Error('Falha ao gerar blob.'));
      },
      mimeType,
      quality / 100,
    );
  });
}

// ─── Converte para SVG (rasterização reversa — embeds raster em SVG) ─────────
async function convertToSvg(file: File): Promise<Blob> {
  const url = URL.createObjectURL(file);
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => {
      URL.revokeObjectURL(url);
      const w = img.naturalWidth;
      const h = img.naturalHeight;
      // Cria SVG que incorpora a imagem como base64
      const canvas = document.createElement('canvas');
      canvas.width = w;
      canvas.height = h;
      const ctx = canvas.getContext('2d');
      if (!ctx) { reject(new Error('Canvas não suportado.')); return; }
      ctx.drawImage(img, 0, 0);
      const dataUrl = canvas.toDataURL('image/png');
      const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
  <image href="${dataUrl}" width="${w}" height="${h}"/>
</svg>`;
      resolve(new Blob([svg], { type: 'image/svg+xml' }));
    };
    img.onerror = () => { URL.revokeObjectURL(url); reject(new Error('Erro ao carregar imagem.')); };
    img.src = url;
  });
}

// ─── Função principal de conversão ──────────────────────────────────────────
export async function convertImage(
  file: File,
  format: ImageFormat,
  quality: number = 85,
): Promise<ConversionResult> {
  const start = performance.now();
  const mime = getMimeType(format);

  let blob: Blob;

  if (format === 'svg') {
    // Qualquer raster → SVG (embed)
    blob = await convertToSvg(file);
  } else if (file.type === 'image/svg+xml') {
    // SVG → raster
    const img = await loadSvgAsImage(file);
    blob = await imageToBlob(img, mime, quality);
  } else if (format === 'gif') {
    // GIF: canvas só gera PNG/JPEG/WebP nativamente
    // Usamos canvas→PNG e re-emite como GIF (estático)
    // Para GIFs animados mantemos o arquivo original se já for GIF
    if (file.type === 'image/gif') {
      blob = file; // Mantém GIF animado original
    } else {
      const img = await loadImage(file);
      // canvas.toBlob não suporta GIF nativo; exportamos como PNG e renomeamos
      blob = await imageToBlob(img, 'image/png', quality);
      blob = new Blob([blob], { type: 'image/gif' }); // Re-tag como gif (estático)
    }
  } else {
    const img = await loadImage(file);
    blob = await imageToBlob(img, mime, quality);
  }

  // Dimensões: recarregar do blob para obter w/h finais
  let width = 0;
  let height = 0;
  if (format !== 'svg') {
    try {
      const blobUrl = URL.createObjectURL(blob);
      await new Promise<void>((res) => {
        const i = new Image();
        i.onload = () => { width = i.naturalWidth; height = i.naturalHeight; URL.revokeObjectURL(blobUrl); res(); };
        i.onerror = () => { URL.revokeObjectURL(blobUrl); res(); };
        i.src = blobUrl;
      });
    } catch { /* ignora */ }
  }

  const url = URL.createObjectURL(blob);
  const durationMs = Math.round(performance.now() - start);

  return { blob, url, width, height, sizeBytes: blob.size, durationMs };
}
