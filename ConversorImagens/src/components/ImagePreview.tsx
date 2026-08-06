import { Eye, ArrowRight, Info } from 'lucide-react';
import type { ConversionResult } from '@/lib/imageConverter';
import type { ImageFormat } from '@/lib/constants';
import { formatFileSize, calcSizeReduction, formatTime } from '@/lib/formatUtils';

interface ImagePreviewProps {
  originalFile: File;
  originalPreviewUrl: string;
  conversionResult: ConversionResult;
  format: ImageFormat;
}

export function ImagePreview({
  originalFile,
  originalPreviewUrl,
  conversionResult,
  format,
}: ImagePreviewProps) {
  const reduction = calcSizeReduction(originalFile.size, conversionResult.sizeBytes);
  const isSmaller = reduction > 0;
  const isSvg = format === 'svg';

  return (
    <div className="flex flex-col gap-4 animate-fadeIn">
      {/* Header */}
      <div className="flex items-center gap-2">
        <div className="feature-icon w-8 h-8">
          <Eye size={16} color="#fff" />
        </div>
        <h2 style={{ fontSize: '1rem', fontWeight: 700, color: 'var(--text-primary)' }}>
          Pré-visualização
        </h2>
        <div className="flex items-center gap-1 ml-auto">
          <span className="badge badge-green">✓ Convertido</span>
          <span
            className="badge"
            style={{ background: `rgba(0,0,0,0.05)`, color: 'var(--text-secondary)', fontSize: '0.7rem' }}
          >
            {formatTime(conversionResult.durationMs)}
          </span>
        </div>
      </div>

      {/* Comparação antes / depois */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: '1fr auto 1fr',
          gap: 10,
          alignItems: 'center',
        }}
      >
        {/* Original */}
        <div className="flex flex-col gap-2">
          <p style={{ fontSize: '0.72rem', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em' }}>
            Original
          </p>
          <div
            style={{
              borderRadius: 'var(--radius-md)',
              overflow: 'hidden',
              background: 'repeating-conic-gradient(#ddd 0% 25%, #f4f4f4 0% 50%) 0 0 / 14px 14px',
              aspectRatio: '4/3',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <img
              src={originalPreviewUrl}
              alt="Imagem original"
              style={{ maxWidth: '100%', maxHeight: '100%', objectFit: 'contain', display: 'block' }}
            />
          </div>
          <div className="glass-card-inner" style={{ padding: '8px 12px' }}>
            <p style={{ fontSize: '0.78rem', fontWeight: 600, color: 'var(--text-primary)' }}>
              {formatFileSize(originalFile.size)}
            </p>
            <p style={{ fontSize: '0.72rem', color: 'var(--text-muted)' }}>
              {originalFile.type.split('/')[1].toUpperCase()}
            </p>
          </div>
        </div>

        {/* Seta */}
        <div
          style={{
            width: 36,
            height: 36,
            borderRadius: '50%',
            background: 'var(--primary)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}
        >
          <ArrowRight size={18} color="#fff" />
        </div>

        {/* Convertido */}
        <div className="flex flex-col gap-2">
          <p style={{ fontSize: '0.72rem', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em' }}>
            Convertido
          </p>
          <div
            style={{
              borderRadius: 'var(--radius-md)',
              overflow: 'hidden',
              background: 'repeating-conic-gradient(#ddd 0% 25%, #f4f4f4 0% 50%) 0 0 / 14px 14px',
              aspectRatio: '4/3',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              border: '2px solid rgba(111,124,96,0.3)',
            }}
          >
            {isSvg ? (
              <img
                src={conversionResult.url}
                alt="Imagem convertida SVG"
                style={{ maxWidth: '100%', maxHeight: '100%', objectFit: 'contain', display: 'block' }}
              />
            ) : (
              <img
                src={conversionResult.url}
                alt={`Imagem convertida para ${format.toUpperCase()}`}
                style={{ maxWidth: '100%', maxHeight: '100%', objectFit: 'contain', display: 'block' }}
              />
            )}
          </div>
          <div className="glass-card-inner" style={{ padding: '8px 12px' }}>
            <div className="flex items-center justify-between">
              <p style={{ fontSize: '0.78rem', fontWeight: 600, color: 'var(--text-primary)' }}>
                {formatFileSize(conversionResult.sizeBytes)}
              </p>
              {reduction !== 0 && (
                <span
                  className="badge"
                  style={{
                    background: isSmaller ? 'rgba(111,124,96,0.1)' : 'rgba(217,83,79,0.1)',
                    color: isSmaller ? 'var(--primary)' : '#d9534f',
                    fontSize: '0.68rem',
                  }}
                >
                  {isSmaller ? `−${reduction}%` : `+${Math.abs(reduction)}%`}
                </span>
              )}
            </div>
            <p style={{ fontSize: '0.72rem', color: 'var(--text-muted)' }}>
              {format.toUpperCase()}
              {conversionResult.width > 0 && ` · ${conversionResult.width}×${conversionResult.height}px`}
            </p>
          </div>
        </div>
      </div>

      {/* Info extra para transparência */}
      {format === 'jpeg' && originalFile.type === 'image/png' && (
        <div className="toast toast-success" style={{ padding: '10px 14px' }}>
          <Info size={14} style={{ flexShrink: 0 }} />
          <p style={{ fontSize: '0.78rem' }}>
            Transparência preenchida com fundo branco (JPEG não suporta canal alpha).
          </p>
        </div>
      )}
    </div>
  );
}
