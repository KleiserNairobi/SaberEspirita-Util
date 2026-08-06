import { useState, useCallback } from 'react';
import { convertImage, type ConversionResult } from '@/lib/imageConverter';
import type { ImageFormat } from '@/lib/constants';

interface UseImageConverterReturn {
  convertedResult: ConversionResult | null;
  isConverting: boolean;
  error: string | null;
  convert: (file: File, format: ImageFormat, quality: number) => Promise<void>;
  reset: () => void;
}

export function useImageConverter(): UseImageConverterReturn {
  const [convertedResult, setConvertedResult] = useState<ConversionResult | null>(null);
  const [isConverting, setIsConverting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const convert = useCallback(async (file: File, format: ImageFormat, quality: number) => {
    setIsConverting(true);
    setError(null);

    // Revoga URL anterior para evitar memory leak
    if (convertedResult?.url) {
      URL.revokeObjectURL(convertedResult.url);
    }

    try {
      const result = await convertImage(file, format, quality);
      setConvertedResult(result);
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Erro desconhecido ao converter imagem.';
      setError(msg);
      setConvertedResult(null);
    } finally {
      setIsConverting(false);
    }
  }, [convertedResult]);

  const reset = useCallback(() => {
    if (convertedResult?.url) {
      URL.revokeObjectURL(convertedResult.url);
    }
    setConvertedResult(null);
    setError(null);
    setIsConverting(false);
  }, [convertedResult]);

  return { convertedResult, isConverting, error, convert, reset };
}
