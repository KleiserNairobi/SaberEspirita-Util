import { useRef, useEffect } from 'react';
import { Gauge } from 'lucide-react';
import { DEFAULT_QUALITY, type ImageFormat } from '@/lib/constants';

interface QualitySliderProps {
  quality: number;
  format: ImageFormat;
  onChange: (quality: number) => void;
}

const QUALITY_LABELS: Record<number, { label: string; color: string }> = {
  20: { label: 'Mínima', color: '#d9534f' },
  40: { label: 'Baixa', color: '#e8774a' },
  60: { label: 'Média', color: '#f0a030' },
  75: { label: 'Boa', color: '#7aac60' },
  85: { label: 'Alta', color: 'var(--primary)' },
  95: { label: 'Máxima', color: '#3a8a6a' },
};

function getQualityLabel(q: number): { label: string; color: string } {
  const keys = Object.keys(QUALITY_LABELS).map(Number).sort((a, b) => a - b);
  let best = keys[0];
  for (const k of keys) {
    if (q >= k) best = k;
  }
  return QUALITY_LABELS[best];
}

const FORMATS_WITH_QUALITY: ImageFormat[] = ['jpeg', 'webp'];

export function QualitySlider({ quality, format, onChange }: QualitySliderProps) {
  const sliderRef = useRef<HTMLInputElement>(null);

  // Atualiza variável CSS para fill do slider
  useEffect(() => {
    if (sliderRef.current) {
      sliderRef.current.style.setProperty('--slider-pct', `${quality}%`);
    }
  }, [quality]);

  if (!FORMATS_WITH_QUALITY.includes(format)) {
    return (
      <div
        className="glass-card-inner"
        style={{ padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 10 }}
      >
        <Gauge size={16} color="var(--text-muted)" />
        <p style={{ fontSize: '0.82rem', color: 'var(--text-muted)' }}>
          Qualidade não configurável para{' '}
          <strong style={{ textTransform: 'uppercase' }}>{format}</strong>
        </p>
      </div>
    );
  }

  const qlInfo = getQualityLabel(quality);

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Gauge size={15} color="var(--primary)" />
          <p style={{ fontSize: '0.8rem', fontWeight: 600, color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.06em' }}>
            Qualidade
          </p>
        </div>
        <div className="flex items-center gap-2">
          <span
            className="badge"
            style={{ background: `${qlInfo.color}18`, color: qlInfo.color, fontSize: '0.72rem' }}
          >
            {qlInfo.label}
          </span>
          <span
            style={{
              fontSize: '1rem',
              fontWeight: 800,
              color: 'var(--primary)',
              minWidth: 36,
              textAlign: 'right',
            }}
          >
            {quality}%
          </span>
        </div>
      </div>

      <input
        ref={sliderRef}
        id="quality-slider"
        type="range"
        min={1}
        max={100}
        value={quality}
        onChange={(e) => onChange(Number(e.target.value))}
        className="slider-track"
        aria-label="Controle de qualidade da imagem"
        aria-valuemin={1}
        aria-valuemax={100}
        aria-valuenow={quality}
        aria-valuetext={`${quality}% — ${qlInfo.label}`}
        style={{ '--slider-pct': `${quality}%` } as React.CSSProperties}
      />

      {/* Marcadores */}
      <div className="flex justify-between">
        {[1, 25, 50, 75, 100].map((v) => (
          <button
            key={v}
            onClick={() => onChange(v)}
            style={{
              background: 'none',
              border: 'none',
              cursor: 'pointer',
              fontSize: '0.72rem',
              color: Math.abs(quality - v) < 10 ? 'var(--primary)' : 'var(--text-muted)',
              fontWeight: Math.abs(quality - v) < 10 ? 700 : 400,
              padding: '2px 4px',
              fontFamily: 'Inter, sans-serif',
              transition: 'color 0.2s',
            }}
          >
            {v}%
          </button>
        ))}
      </div>

      {/* Dica */}
      <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
        💡 {quality >= 85
          ? 'Alta qualidade — recomendado para uso profissional'
          : quality >= 65
          ? 'Bom equilíbrio entre qualidade e tamanho de arquivo'
          : 'Menor qualidade — tamanho de arquivo reduzido'}
      </p>

      {/* Botão resetar */}
      {quality !== DEFAULT_QUALITY && (
        <button
          onClick={() => onChange(DEFAULT_QUALITY)}
          className="btn-ghost"
          style={{ padding: '6px 12px', fontSize: '0.78rem', alignSelf: 'flex-start' }}
        >
          Restaurar padrão ({DEFAULT_QUALITY}%)
        </button>
      )}
    </div>
  );
}
