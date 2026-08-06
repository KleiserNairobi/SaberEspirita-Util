import type { ImageFormat } from '@/lib/constants';
import { FormatSelector } from './FormatSelector';
import { QualitySlider } from './QualitySlider';
import { Settings2 } from 'lucide-react';

interface ConversionOptionsProps {
  selectedFormat: ImageFormat;
  quality: number;
  onFormatChange: (format: ImageFormat) => void;
  onQualityChange: (quality: number) => void;
  sourceFormat?: string;
  hasImage: boolean;
}

export function ConversionOptions({
  selectedFormat,
  quality,
  onFormatChange,
  onQualityChange,
  sourceFormat,
  hasImage,
}: ConversionOptionsProps) {
  return (
    <div className="flex flex-col gap-5">
      {/* Header */}
      <div className="flex items-center gap-2">
        <div className="feature-icon w-8 h-8">
          <Settings2 size={16} color="#fff" />
        </div>
        <h2 style={{ fontSize: '1rem', fontWeight: 700, color: 'var(--text-primary)' }}>
          Opções de Conversão
        </h2>
      </div>

      {/* Conteúdo */}
      <div className={`flex flex-col gap-5 transition-opacity duration-300${hasImage ? '' : ' opacity-50 pointer-events-none'}`}>
        <FormatSelector
          selectedFormat={selectedFormat}
          onFormatChange={onFormatChange}
          sourceFormat={sourceFormat}
        />

        <hr className="divider" />

        <QualitySlider
          quality={quality}
          format={selectedFormat}
          onChange={onQualityChange}
        />
      </div>

      {/* Prompt quando não há imagem */}
      {!hasImage && (
        <p style={{ fontSize: '0.82rem', color: 'var(--text-muted)', textAlign: 'center', marginTop: -8 }}>
          Selecione uma imagem para configurar as opções
        </p>
      )}
    </div>
  );
}
