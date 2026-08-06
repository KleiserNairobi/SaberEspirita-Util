import { useState, useCallback } from 'react';
import { VALIDATION_LIMITS } from '@/lib/constants';
import { isImageFile } from '@/lib/formatUtils';

interface ValidationResult {
  isValid: boolean;
  errorMessage: string | null;
}

interface UseImageValidationReturn {
  validate: (file: File) => Promise<ValidationResult>;
  isValidating: boolean;
}

export function useImageValidation(): UseImageValidationReturn {
  const [isValidating, setIsValidating] = useState(false);

  const validate = useCallback(async (file: File): Promise<ValidationResult> => {
    setIsValidating(true);

    try {
      // Verifica tipo MIME
      if (!isImageFile(file)) {
        return { isValid: false, errorMessage: 'Arquivo não é uma imagem válida.' };
      }

      // Verifica tamanho
      if (file.size > VALIDATION_LIMITS.maxFileSizeBytes) {
        return {
          isValid: false,
          errorMessage: `Arquivo muito grande. Máximo permitido: ${VALIDATION_LIMITS.maxFileSizeMB}MB.`,
        };
      }

      // Verifica dimensões para imagens raster
      if (file.type !== 'image/svg+xml') {
        const dimensionCheck = await checkImageDimensions(file);
        if (!dimensionCheck.isValid) return dimensionCheck;
      }

      return { isValid: true, errorMessage: null };
    } finally {
      setIsValidating(false);
    }
  }, []);

  return { validate, isValidating };
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
function checkImageDimensions(file: File): Promise<ValidationResult> {
  return new Promise((resolve) => {
    const url = URL.createObjectURL(file);
    const img = new Image();

    img.onload = () => {
      URL.revokeObjectURL(url);
      const { naturalWidth: w, naturalHeight: h } = img;

      if (w < VALIDATION_LIMITS.minDimension || h < VALIDATION_LIMITS.minDimension) {
        resolve({ isValid: false, errorMessage: 'Imagem muito pequena (mínimo 1×1px).' });
        return;
      }

      if (w > VALIDATION_LIMITS.maxDimension || h > VALIDATION_LIMITS.maxDimension) {
        resolve({
          isValid: false,
          errorMessage: `Imagem muito grande. Máximo: ${VALIDATION_LIMITS.maxDimension}×${VALIDATION_LIMITS.maxDimension}px.`,
        });
        return;
      }

      resolve({ isValid: true, errorMessage: null });
    };

    img.onerror = () => {
      URL.revokeObjectURL(url);
      resolve({ isValid: false, errorMessage: 'Não foi possível ler as dimensões da imagem.' });
    };

    img.src = url;
  });
}
