import { SUPPORTED_FORMATS, type ImageFormat } from '@/lib/constants';

interface FormatSelectorProps {
  selectedFormat: ImageFormat;
  onFormatChange: (format: ImageFormat) => void;
  sourceFormat?: string;
}

const FORMAT_DETAILS: Record<ImageFormat, { benefit: string; icon: string }> = {
  png:  { benefit: 'Sem perda de qualidade', icon: '🖼️' },
  jpeg: { benefit: 'Menor tamanho de arquivo', icon: '📸' },
  webp: { benefit: 'Melhor custo-benefício', icon: '🌐' },
  gif:  { benefit: 'Preserva animações', icon: '🎞️' },
  svg:  { benefit: 'Escalável infinitamente', icon: '✏️' },
};

export function FormatSelector({ selectedFormat, onFormatChange, sourceFormat }: FormatSelectorProps) {
  return (
    <div className="flex flex-col gap-3">
      <div>
        <p style={{ fontSize: '0.8rem', fontWeight: 600, color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 10 }}>
          Formato de Saída
        </p>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(5, 1fr)',
            gap: 8,
          }}
        >
          {SUPPORTED_FORMATS.map((fmt) => {
            const isSelected = selectedFormat === fmt.id;
            const isSameAsSource = sourceFormat === fmt.mimeType;
            return (
              <button
                key={fmt.id}
                id={`format-btn-${fmt.id}`}
                className={`format-card${isSelected ? ' selected' : ''}`}
                onClick={() => onFormatChange(fmt.id)}
                title={fmt.description}
                aria-pressed={isSelected}
                aria-label={`Converter para ${fmt.label}`}
              >
                <span style={{ fontSize: '1.4rem', lineHeight: 1 }}>{FORMAT_DETAILS[fmt.id].icon}</span>
                <span
                  style={{
                    fontSize: '0.78rem',
                    fontWeight: 700,
                    color: isSelected ? 'var(--primary)' : 'var(--text-primary)',
                    letterSpacing: '0.04em',
                  }}
                >
                  {fmt.label}
                </span>
                {isSameAsSource && (
                  <span className="badge badge-green" style={{ fontSize: '0.62rem', padding: '1px 6px' }}>
                    Atual
                  </span>
                )}
              </button>
            );
          })}
        </div>
      </div>

      {/* Descrição do formato selecionado */}
      <div
        className="glass-card-inner animate-fadeIn"
        style={{ padding: '10px 14px', display: 'flex', alignItems: 'center', gap: 10 }}
        key={selectedFormat}
      >
        <span style={{ fontSize: '1.1rem' }}>{FORMAT_DETAILS[selectedFormat].icon}</span>
        <div>
          <p style={{ fontSize: '0.82rem', fontWeight: 600, color: 'var(--primary)' }}>
            {SUPPORTED_FORMATS.find(f => f.id === selectedFormat)?.label}
          </p>
          <p style={{ fontSize: '0.77rem', color: 'var(--text-secondary)' }}>
            {FORMAT_DETAILS[selectedFormat].benefit} ·{' '}
            {SUPPORTED_FORMATS.find(f => f.id === selectedFormat)?.description}
          </p>
        </div>
      </div>
    </div>
  );
}
