import { Download, Loader2, RefreshCcw } from 'lucide-react';
import type { ConversionResult } from '@/lib/imageConverter';
import type { ImageFormat } from '@/lib/constants';
import { suggestFilename, formatFileSize } from '@/lib/formatUtils';

interface DownloadButtonProps {
  conversionResult: ConversionResult | null;
  originalFile: File | null;
  format: ImageFormat;
  quality: number;
  isConverting: boolean;
  onConvert: () => void;
  onReset: () => void;
}

export function DownloadButton({
  conversionResult,
  originalFile,
  format,
  quality: _quality,
  isConverting,
  onConvert,
  onReset,
}: DownloadButtonProps) {
  const handleDownload = async () => {
    if (!conversionResult || !originalFile) return;

    const filename = suggestFilename(originalFile.name, format);
    const blob = new Blob([conversionResult.blob], { type: conversionResult.blob.type });

    // ── File System Access API (Chrome 86+ / Edge 86+) ──────────────────────
    // Abre o diálogo nativo "Salvar Como" do sistema operacional
    if ('showSaveFilePicker' in window) {
      try {
        const ext = filename.split('.').pop() ?? format;
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const fileHandle = await (window as any).showSaveFilePicker({
          suggestedName: filename,
          types: [
            {
              description: `Imagem ${format.toUpperCase()}`,
              accept: { [blob.type]: [`.${ext}`] },
            },
          ],
        });
        const writable = await fileHandle.createWritable();
        await writable.write(blob);
        await writable.close();
        return; // sucesso — sai aqui
      } catch (err) {
        // Usuário cancelou o diálogo — não faz nada
        if (err instanceof Error && err.name === 'AbortError') return;
        // Qualquer outro erro: cai no fallback abaixo
      }
    }

    // ── Fallback: anchor + blob URL ──────────────────────────────────────────
    const downloadUrl = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = downloadUrl;
    a.download = filename;
    a.style.display = 'none';
    document.body.appendChild(a);
    a.click();
    setTimeout(() => {
      URL.revokeObjectURL(downloadUrl);
      document.body.removeChild(a);
    }, 300);
  };

  return (
    <div className="flex flex-col gap-3">
      {/* Botão principal de conversão / download */}
      <div className="flex gap-3">
        {conversionResult ? (
          <button
            id="download-btn"
            className="btn-accent flex-1"
            onClick={handleDownload}
            style={{ padding: '14px 20px', fontSize: '0.95rem', borderRadius: 'var(--radius-md)' }}
          >
            <Download size={18} />
            Baixar {format.toUpperCase()}
            <span
              style={{
                fontSize: '0.75rem',
                fontWeight: 500,
                opacity: 0.75,
                marginLeft: 4,
              }}
            >
              ({formatFileSize(conversionResult.sizeBytes)})
            </span>
          </button>
        ) : (
          <button
            id="convert-btn"
            className="btn-primary flex-1"
            onClick={onConvert}
            disabled={!originalFile || isConverting}
            style={{ padding: '14px 20px', fontSize: '0.95rem', borderRadius: 'var(--radius-md)' }}
          >
            {isConverting ? (
              <>
                <Loader2 size={18} className="animate-spin" />
                Convertendo...
              </>
            ) : (
              <>
                <RefreshCcw size={18} />
                Converter para {format.toUpperCase()}
              </>
            )}
          </button>
        )}

        {/* Botão nova conversão */}
        {conversionResult && (
          <button
            id="new-conversion-btn"
            className="btn-ghost"
            onClick={onReset}
            style={{ padding: '14px 16px' }}
            title="Nova conversão"
            aria-label="Iniciar nova conversão"
          >
            <RefreshCcw size={18} />
          </button>
        )}
      </div>

      {/* Reconstruir quando muda formato */}
      {conversionResult && originalFile && (
        <button
          id="reconvert-btn"
          className="btn-ghost"
          onClick={onConvert}
          disabled={isConverting}
          style={{ fontSize: '0.82rem', padding: '8px 14px' }}
        >
          {isConverting ? (
            <><Loader2 size={14} className="animate-spin" /> Reconvertendo...</>
          ) : (
            <><RefreshCcw size={14} /> Reconverter com novas opções</>
          )}
        </button>
      )}
    </div>
  );
}
