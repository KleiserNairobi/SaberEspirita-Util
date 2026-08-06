import { useState, useCallback, useEffect, useRef } from 'react';
import { ImageUploader } from '@/components/ImageUploader';
import { ConversionOptions } from '@/components/ConversionOptions';
import { ImagePreview } from '@/components/ImagePreview';
import { DownloadButton } from '@/components/DownloadButton';
import { useImageConverter } from '@/hooks/useImageConverter';
import { DEFAULT_QUALITY, type ImageFormat } from '@/lib/constants';
import { Shield, Zap, Wifi, Star } from 'lucide-react';

// ─── Seção de benefícios ─────────────────────────────────────────────────────
const BENEFITS = [
  { icon: Shield, label: '100% Privado', desc: 'Sem envio de dados', color: '#6f7c60' },
  { icon: Zap, label: 'Instantâneo', desc: 'Processamento local', color: '#ffd764' },
  { icon: Wifi, label: 'Offline', desc: 'Funciona sem internet', color: '#4a90d9' },
  { icon: Star, label: 'Ilimitado', desc: 'Sem restrições de uso', color: '#a970c4' },
];

export default function Home() {
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [originalPreviewUrl, setOriginalPreviewUrl] = useState<string | null>(null);
  const [format, setFormat] = useState<ImageFormat>('webp');
  const [quality, setQuality] = useState(DEFAULT_QUALITY);

  const { convertedResult, isConverting, error, convert, reset } = useImageConverter();

  // Ref para IntersectionObserver das seções
  const sectionsRef = useRef<HTMLElement[]>([]);

  // IntersectionObserver para animações section-fade
  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add('visible');
          }
        });
      },
      { threshold: 0.1 },
    );

    const sections = document.querySelectorAll('.section-fade');
    sections.forEach((el) => observer.observe(el));
    sectionsRef.current = Array.from(sections) as HTMLElement[];

    return () => observer.disconnect();
  }, [selectedFile, convertedResult]);

  // ─── Handlers ───────────────────────────────────────────────────────────────
  const handleImageSelected = useCallback((file: File) => {
    // Revoga URL anterior
    if (originalPreviewUrl) URL.revokeObjectURL(originalPreviewUrl);

    const previewUrl = URL.createObjectURL(file);
    setSelectedFile(file);
    setOriginalPreviewUrl(previewUrl);
    reset();
  }, [originalPreviewUrl, reset]);

  const handleConvert = useCallback(async () => {
    if (!selectedFile) return;
    await convert(selectedFile, format, quality);
  }, [selectedFile, format, quality, convert]);

  const handleReset = useCallback(() => {
    if (originalPreviewUrl) URL.revokeObjectURL(originalPreviewUrl);
    setSelectedFile(null);
    setOriginalPreviewUrl(null);
    reset();
  }, [originalPreviewUrl, reset]);

  // Cleanup ao desmontar
  useEffect(() => {
    return () => {
      if (originalPreviewUrl) URL.revokeObjectURL(originalPreviewUrl);
    };
  }, [originalPreviewUrl]);

  return (
    <div style={{ minHeight: '100dvh', background: 'var(--bg)' }}>

      {/* ── Decoração de fundo ─────────────────────────────────────────────── */}
      <div
        style={{
          position: 'fixed',
          inset: 0,
          pointerEvents: 'none',
          zIndex: 0,
          overflow: 'hidden',
        }}
      >
        <div className="glow-green" style={{ position: 'absolute', inset: 0 }} />
        <div
          className="vine-pattern"
          style={{ position: 'absolute', inset: 0, opacity: 0.6 }}
        />
      </div>

      <div style={{ position: 'relative', zIndex: 1 }}>

        {/* ── Header ──────────────────────────────────────────────────────── */}
        <header
          style={{
            padding: '20px 24px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            maxWidth: 1100,
            margin: '0 auto',
          }}
        >
          <div className="flex items-center gap-3">
            <div
              style={{
                width: 40,
                height: 40,
                borderRadius: 12,
                background: 'linear-gradient(135deg, var(--primary) 0%, var(--secondary) 100%)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: '1.2rem',
                boxShadow: 'var(--shadow-md)',
              }}
            >
              🖼️
            </div>
            <div>
              <h1 style={{ fontSize: '1.05rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.1 }}>
                Conversor de Imagens
              </h1>
              <p style={{ fontSize: '0.72rem', color: 'var(--text-muted)', fontWeight: 500 }}>
                100% local · sem uploads
              </p>
            </div>
          </div>

          {/* Badges de benefícios no header (desktop) */}
          <div
            className="hidden md:flex items-center gap-2"
            style={{ display: 'flex', gap: 8 }}
          >
            {BENEFITS.map(({ icon: Icon, label, color }) => (
              <div
                key={label}
                className="glass-card-inner flex items-center gap-1.5"
                style={{ padding: '6px 12px', display: 'flex', alignItems: 'center', gap: 6, borderRadius: 99 }}
              >
                <Icon size={13} color={color} />
                <span style={{ fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-secondary)' }}>
                  {label}
                </span>
              </div>
            ))}
          </div>
        </header>

        {/* ── Hero / Tagline ───────────────────────────────────────────────── */}
        <section
          className="section-fade"
          style={{
            textAlign: 'center',
            padding: '8px 24px 32px',
            maxWidth: 680,
            margin: '0 auto',
          }}
        >
          <h2
            style={{
              fontSize: 'clamp(1.6rem, 4vw, 2.4rem)',
              fontWeight: 800,
              lineHeight: 1.2,
              color: 'var(--text-primary)',
              marginBottom: 12,
            }}
          >
            Converta imagens{' '}
            <span className="text-gradient">no seu navegador</span>
          </h2>
          <p style={{ fontSize: '1rem', color: 'var(--text-secondary)', lineHeight: 1.6, maxWidth: 480, margin: '0 auto' }}>
            PNG, JPEG, WebP, GIF e SVG — sem limites, sem cadastro,
            sem enviar seus arquivos para a internet.
          </p>
        </section>

        {/* ── Main Card ────────────────────────────────────────────────────── */}
        <main
          style={{
            maxWidth: 1100,
            margin: '0 auto',
            padding: '0 20px 60px',
            display: 'flex',
            flexDirection: 'column',
            gap: 20,
          }}
        >
          {/* Linha 1: Upload + Preview (mesma altura) */}
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
              gap: 20,
              alignItems: 'stretch',
            }}
          >
            {/* Card de Upload */}
            <section
              className="glass-card section-fade"
              style={{ padding: 24, display: 'flex', flexDirection: 'column' }}
              aria-label="Upload de imagem"
            >
              <ImageUploader
                onImageSelected={handleImageSelected}
                isLoading={isConverting}
                currentFile={selectedFile}
              />
            </section>

            {/* Card de Preview */}
            {convertedResult && selectedFile && originalPreviewUrl ? (
              <section
                className="glass-card section-fade"
                style={{ padding: 24 }}
                aria-label="Pré-visualização da conversão"
              >
                <ImagePreview
                  originalFile={selectedFile}
                  originalPreviewUrl={originalPreviewUrl}
                  conversionResult={convertedResult}
                  format={format}
                />
              </section>
            ) : (
              <section
                className="glass-card section-fade flex flex-col items-center justify-center"
                style={{ padding: 40, textAlign: 'center' }}
                aria-label="Área de pré-visualização"
              >
                {/* Placeholder visual */}
                <div
                  style={{
                    width: 100,
                    height: 100,
                    borderRadius: '50%',
                    background: 'linear-gradient(135deg, var(--primary-light) 0%, rgba(131,146,120,0.2) 100%)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: '2.5rem',
                    marginBottom: 20,
                  }}
                >
                  🖼️
                </div>
                <h3 style={{ fontSize: '1.1rem', fontWeight: 700, color: 'var(--text-primary)', marginBottom: 8 }}>
                  Pré-visualização
                </h3>
                <p style={{ fontSize: '0.88rem', color: 'var(--text-muted)', lineHeight: 1.6 }}>
                  {selectedFile
                    ? 'Clique em "Converter" para ver a prévia da imagem processada'
                    : 'Selecione uma imagem para começar a conversão'}
                </p>

                {isConverting && (
                  <div className="flex flex-col items-center gap-3 mt-6 animate-fadeIn">
                    <div className="progress-bar" style={{ width: 180 }}>
                      <div
                        className="progress-bar-fill animate-pulse-ring"
                        style={{ width: '60%' }}
                      />
                    </div>
                    <p style={{ fontSize: '0.82rem', color: 'var(--primary)', fontWeight: 600 }}>
                      Processando imagem...
                    </p>
                  </div>
                )}

                {error && (
                  <div className="toast toast-error animate-fadeIn" style={{ marginTop: 16, maxWidth: 320 }}>
                    <span style={{ fontSize: '0.85rem' }}>{error}</span>
                  </div>
                )}
              </section>
            )}
          </div>

          {/* Linha 2: Opções + Download */}
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
              gap: 20,
              alignItems: 'start',
            }}
          >
            {/* Card de Opções */}
            <section className="glass-card section-fade" style={{ padding: 24 }} aria-label="Opções de conversão">
              <ConversionOptions
                selectedFormat={format}
                quality={quality}
                onFormatChange={setFormat}
                onQualityChange={setQuality}
                sourceFormat={selectedFile?.type}
                hasImage={!!selectedFile}
              />
            </section>

            {/* Botão de Conversão / Download */}
            <div className="section-fade flex flex-col justify-center" style={{ gap: 0 }}>
              <DownloadButton
                conversionResult={convertedResult}
                originalFile={selectedFile}
                format={format}
                quality={quality}
                isConverting={isConverting}
                onConvert={handleConvert}
                onReset={handleReset}
              />
            </div>
          </div>
        </main>

        {/* ── Rodapé ──────────────────────────────────────────────────────── */}
        <footer
          style={{
            textAlign: 'center',
            padding: '20px 24px 32px',
            borderTop: '1px solid var(--border)',
          }}
        >
          <p style={{ fontSize: '0.78rem', color: 'var(--text-muted)' }}>
            Conversor de Imagens Local · Seus arquivos nunca saem do seu dispositivo · Julho 2026
          </p>
        </footer>
      </div>
    </div>
  );
}
