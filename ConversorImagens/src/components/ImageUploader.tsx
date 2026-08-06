import { useRef, useState, useCallback } from 'react';
import { Upload, ImageIcon, AlertCircle, Loader2 } from 'lucide-react';
import { ACCEPTED_MIME_TYPES } from '@/lib/constants';
import { formatFileSize } from '@/lib/formatUtils';
import { useImageValidation } from '@/hooks/useImageValidation';

interface ImageUploaderProps {
  onImageSelected: (file: File) => void;
  isLoading?: boolean;
  currentFile?: File | null;
}

export function ImageUploader({ onImageSelected, isLoading = false, currentFile }: ImageUploaderProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [validationError, setValidationError] = useState<string | null>(null);
  const { validate, isValidating } = useImageValidation();

  const busy = isLoading || isValidating;

  const handleFile = useCallback(async (file: File) => {
    setValidationError(null);
    const result = await validate(file);
    if (!result.isValid) {
      setValidationError(result.errorMessage);
      return;
    }
    onImageSelected(file);
  }, [validate, onImageSelected]);

  // ─── Eventos de arquivo ────────────────────────────────────────────────────
  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) handleFile(file);
    e.target.value = '';
  };

  // ─── Drag-and-Drop ─────────────────────────────────────────────────────────
  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  };
  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
  };
  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    const file = e.dataTransfer.files?.[0];
    if (file) handleFile(file);
  };

  // ─── Paste (Ctrl+V) ────────────────────────────────────────────────────────
  const handlePaste = useCallback((e: React.ClipboardEvent) => {
    const items = e.clipboardData.items;
    for (const item of items) {
      if (item.kind === 'file' && item.type.startsWith('image/')) {
        const file = item.getAsFile();
        if (file) { handleFile(file); break; }
      }
    }
  }, [handleFile]);

  return (
    <div className="flex flex-col gap-4">
      {/* Label */}
      <div className="flex items-center gap-2">
        <div className="feature-icon w-8 h-8">
          <ImageIcon size={16} color="#fff" />
        </div>
        <h2 style={{ fontSize: '1rem', fontWeight: 700, color: 'var(--text-primary)' }}>
          Selecionar Imagem
        </h2>
      </div>

      {/* Drop zone */}
      <div
        className={`drop-zone flex flex-col items-center justify-center gap-4 p-10 select-none outline-none${
          isDragging ? ' dragging' : ''
        }${validationError ? ' error-state' : ''}`}
        tabIndex={0}
        role="button"
        aria-label="Área de upload de imagem — clique ou arraste uma imagem"
        onClick={() => !busy && inputRef.current?.click()}
        onKeyDown={(e) => e.key === 'Enter' && !busy && inputRef.current?.click()}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
        onPaste={handlePaste}
      >
        {busy ? (
          <div className="flex flex-col items-center gap-3">
            <Loader2 size={40} className="animate-spin" color="var(--primary)" />
            <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', fontWeight: 500 }}>
              {isValidating ? 'Validando arquivo...' : 'Carregando...'}
            </p>
          </div>
        ) : isDragging ? (
          <div className="flex flex-col items-center gap-3 animate-fadeIn">
            <div className="animate-pulse-ring w-16 h-16 rounded-full" style={{ background: 'rgba(111,124,96,0.15)' }} />
            <p style={{ color: 'var(--primary)', fontSize: '1rem', fontWeight: 600 }}>
              Solte a imagem aqui!
            </p>
          </div>
        ) : (
          <div className="flex flex-col items-center gap-3 animate-fadeIn">
            <div
              style={{
                width: 64,
                height: 64,
                borderRadius: '50%',
                background: 'linear-gradient(135deg, var(--primary-light) 0%, rgba(131,146,120,0.3) 100%)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Upload size={28} color="var(--primary)" />
            </div>
            <div style={{ textAlign: 'center' }}>
              <p style={{ color: 'var(--text-primary)', fontSize: '0.95rem', fontWeight: 600 }}>
                Clique para selecionar
              </p>
              <p style={{ color: 'var(--text-secondary)', fontSize: '0.82rem', marginTop: 4 }}>
                ou arraste e solte · Ctrl+V para colar
              </p>
            </div>
            <div className="flex flex-wrap justify-center gap-1" style={{ marginTop: 4 }}>
              {['PNG', 'JPEG', 'WebP', 'GIF', 'SVG'].map((fmt) => (
                <span key={fmt} className="badge badge-green">{fmt}</span>
              ))}
            </div>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.75rem' }}>
              Máximo 50 MB · até 16.000 × 16.000 px
            </p>
          </div>
        )}
      </div>

      {/* Erro de validação */}
      {validationError && (
        <div className="toast toast-error animate-fadeIn">
          <AlertCircle size={16} />
          <span>{validationError}</span>
        </div>
      )}

      {/* Arquivo selecionado */}
      {currentFile && !validationError && (
        <div
          className="glass-card-inner flex items-center gap-3 p-3 animate-fadeIn"
          style={{ padding: '12px 14px' }}
        >
          <div className="feature-icon w-8 h-8 flex-shrink-0">
            <ImageIcon size={14} color="#fff" />
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <p
              style={{
                fontSize: '0.85rem',
                fontWeight: 600,
                color: 'var(--text-primary)',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
              }}
            >
              {currentFile.name}
            </p>
            <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
              {formatFileSize(currentFile.size)}
            </p>
          </div>
          <span className="badge badge-green">Pronto</span>
        </div>
      )}

      {/* Input oculto */}
      <input
        ref={inputRef}
        type="file"
        id="image-file-input"
        accept={ACCEPTED_MIME_TYPES}
        onChange={handleInputChange}
        style={{ display: 'none' }}
        aria-hidden="true"
      />
    </div>
  );
}
