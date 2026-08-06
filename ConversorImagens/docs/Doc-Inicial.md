# Conversor de Imagens Local - Documentação Inicial

## 📋 Visão Geral do Projeto

O **Conversor de Imagens Local** é uma aplicação web estática que funciona 100% no navegador do usuário, permitindo converter imagens entre diferentes formatos sem necessidade de enviar arquivos para servidores externos. A aplicação é offline-first, sem limites de uso, e oferece uma experiência intuitiva e responsiva.

### Características Principais

- ✅ **Funcionamento Local:** Toda a conversão ocorre no navegador, sem envio de dados para servidores
- ✅ **Sem Limites:** Converta quantas imagens quiser, quantas vezes quiser
- ✅ **Múltiplos Formatos:** Suporte para PNG, JPG, WebP, GIF e SVG
- ✅ **Qualidade Configurável:** Controle de compressão para JPG e WebP
- ✅ **Arrastar e Soltar:** Interface intuitiva com drag-and-drop
- ✅ **Visualização em Tempo Real:** Pré-visualização antes do download
- ✅ **Responsivo:** Funciona em desktop, tablet e mobile
- ✅ **Offline:** Funciona completamente offline após o carregamento inicial

---

## 🏗️ Arquitetura Técnica

### Stack de Tecnologias

| Camada | Tecnologia | Versão | Propósito |
|--------|-----------|--------|----------|
| **Frontend Framework** | React | 19.x | Interface e lógica da aplicação |
| **Linguagem** | TypeScript | 5.6+ | Type safety e desenvolvimento robusto |
| **Styling** | Tailwind CSS | 4.x | Design system e responsividade |
| **UI Components** | shadcn/ui | Latest | Componentes reutilizáveis e acessíveis |
| **Roteamento** | Wouter | 3.x | Navegação client-side |
| **Build Tool** | Vite | 7.x | Build rápido e dev server |
| **Processamento de Imagens** | Canvas API + Blob | Native | Conversão nativa do navegador |

### Fluxo de Dados

```
Usuário seleciona/arrasta imagem
        ↓
Arquivo carregado em memória
        ↓
Validação (tipo, tamanho)
        ↓
Pré-visualização renderizada
        ↓
Usuário escolhe formato de saída + qualidade
        ↓
Canvas processa conversão
        ↓
Blob convertido para download
        ↓
Arquivo baixado localmente
```

---

## 🎨 CSS Customizado (index.css)

O arquivo `client/src/index.css` deve incluir o seguinte CSS customizado:

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  background-color: #f2f7f2;
  font-family: "Inter", sans-serif;
  overflow-x: hidden;
}

.text-gradient {
  background: linear-gradient(135deg, #6f7c60 0%, #839278 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.glow-golden {
  background: radial-gradient(
    circle at 70% 30%,
    rgba(255, 215, 100, 0.2) 0%,
    transparent 50%
  );
}

.glow-blue {
  background: radial-gradient(
    circle at 30% 70%,
    rgba(100, 120, 140, 0.15) 0%,
    transparent 50%
  );
}

.vine-pattern {
  background-image: url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M10,30 Q20,20 30,30 T50,30' fill='none' stroke='%23839278' stroke-width='0.5' opacity='0.2'/%3E%3C/svg%3E");
}

.phone-mockup {
  box-shadow:
    0 0 0 12px #ffffff,
    0 25px 50px -12px rgba(0, 0, 0, 0.25),
    0 0 0 1px rgba(0, 0, 0, 0.1);
  border-radius: 40px;
  position: relative;
  overflow: hidden;
}

.phone-notch {
  position: absolute;
  top: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 120px;
  height: 25px;
  background: #ffffff;
  border-bottom-left-radius: 16px;
  border-bottom-right-radius: 16px;
  z-index: 10;
}

.glass-card {
  background: rgba(255, 255, 255, 0.8);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(131, 146, 120, 0.2);
}

.smooth-scroll {
  scroll-behavior: smooth;
}

.btn-primary {
  background-color: #6f7c60;
  transition: all 0.3s ease;
}

.btn-primary:hover {
  background-color: #5a6550;
  transform: translateY(-2px);
  box-shadow: 0 10px 20px -5px rgba(111, 124, 96, 0.4);
}

.feature-icon {
  background: linear-gradient(135deg, #d9e4cc 0%, #839278 100%);
}

.section-fade {
  opacity: 0;
  transform: translateY(30px);
  transition:
    opacity 0.8s ease-out,
    transform 0.8s ease-out;
}

.section-fade.visible {
  opacity: 1;
  transform: translateY(0);
}
```

---

## 📁 Estrutura de Diretórios

```
image-converter-local/
├── client/
│   ├── public/
│   │   ├── favicon.ico
│   │   ├── robots.txt
│   │   └── manifest.json
│   ├── src/
│   │   ├── pages/
│   │   │   ├── Home.tsx              # Página principal com conversor
│   │   │   └── NotFound.tsx          # Página 404
│   │   ├── components/
│   │   │   ├── ui/                   # shadcn/ui components
│   │   │   ├── ImageUploader.tsx     # Componente de upload
│   │   │   ├── ImagePreview.tsx      # Visualização da imagem
│   │   │   ├── ConversionOptions.tsx # Opções de conversão
│   │   │   ├── FormatSelector.tsx    # Seletor de formato
│   │   │   └── DownloadButton.tsx    # Botão de download
│   │   ├── hooks/
│   │   │   ├── useImageConverter.ts  # Lógica de conversão
│   │   │   └── useImageValidation.ts # Validação de imagens
│   │   ├── lib/
│   │   │   ├── imageConverter.ts     # Funções de conversão
│   │   │   ├── formatUtils.ts        # Utilitários de formato
│   │   │   └── constants.ts          # Constantes da app
│   │   ├── contexts/
│   │   │   └── ThemeContext.tsx      # Contexto de tema
│   │   ├── App.tsx                   # Roteador principal
│   │   ├── main.tsx                  # Entry point
│   │   └── index.css                 # Estilos globais
│   └── index.html
├── server/                           # Placeholder (não usado)
├── shared/                           # Placeholder (não usado)
├── package.json
├── tsconfig.json
├── vite.config.ts
├── tailwind.config.ts
└── README.md
```

---

## 🎯 Funcionalidades Detalhadas

### 1. Upload de Imagens

**Métodos de Upload:**
- Clique para selecionar arquivo
- Arrastar e soltar (drag-and-drop)
- Colar imagem da área de transferência

**Validações:**
- Tipo de arquivo (apenas imagens)
- Tamanho máximo: 50MB
- Dimensões mínimas: 1x1px
- Dimensões máximas: 16000x16000px

**Feedback ao Usuário:**
- Indicador de carregamento
- Mensagens de erro claras
- Pré-visualização instantânea

### 2. Seleção de Formato de Saída

**Formatos Suportados:**

| Formato | Extensão | Características | Casos de Uso |
|---------|----------|-----------------|---------------|
| **PNG** | .png | Sem perda, com transparência | Gráficos, logos, screenshots |
| **JPEG** | .jpg | Com perda, comprimido | Fotos, imagens naturais |
| **WebP** | .webp | Com/sem perda, moderno | Web, melhor compressão |
| **GIF** | .gif | Animado ou estático | Memes, animações simples |
| **SVG** | .svg | Vetorial, escalável | Ícones, logos, ilustrações |

### 3. Opções de Conversão

**Para JPEG e WebP:**
- Controle de qualidade (0-100%)
- Pré-visualização do tamanho final
- Recomendações automáticas

**Para PNG:**
- Preservação de transparência
- Otimização de cores

**Para GIF:**
- Detecção automática de animação
- Preservação de frames

**Para SVG:**
- Conversão de SVG para PNG/JPG/WebP (rasterização)
- Conversão de imagens raster para SVG (vetorização - opcional)
- Preservação de qualidade vetorial
- Suporte a animações SVG (quando aplicável)

### 4. Pré-visualização

- Exibição em tempo real da imagem convertida
- Informações: dimensões, tamanho do arquivo, formato
- Comparação antes/depois (opcional)

### 5. Download

- Botão de download com nome sugerido
- Múltiplos downloads sem recarregar
- Histórico de conversões (opcional)

---

## 🎨 Design e UX

### Paleta de Cores e Estilos Customizados

**Cores Principais:**
```css
--background: #f2f7f2           /* Verde claro de fundo */
--primary: #6f7c60              /* Verde musgo principal */
--primary-dark: #5a6550         /* Verde musgo escuro (hover) */
--secondary: #839278            /* Verde cinzento secundário */
--accent: #ffd764               /* Dourado/âmbar para destaques */
--text-primary: #1a1a1a         /* Texto principal */
--text-secondary: #666666       /* Texto secundário */
--border: rgba(131, 146, 120, 0.2)  /* Borda com verde musgo */
--white: #ffffff                /* Branco puro */
```

**Gradientes e Efeitos:**
```css
/* Gradiente de texto */
.text-gradient {
  background: linear-gradient(135deg, #6f7c60 0%, #839278 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

/* Brilho dourado */
.glow-golden {
  background: radial-gradient(
    circle at 70% 30%,
    rgba(255, 215, 100, 0.2) 0%,
    transparent 50%
  );
}

/* Brilho azulado */
.glow-blue {
  background: radial-gradient(
    circle at 30% 70%,
    rgba(100, 120, 140, 0.15) 0%,
    transparent 50%
  );
}

/* Padrão de videiras */
.vine-pattern {
  background-image: url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M10,30 Q20,20 30,30 T50,30' fill='none' stroke='%23839278' stroke-width='0.5' opacity='0.2'/%3E%3C/svg%3E");
}

/* Card com efeito glass */
.glass-card {
  background: rgba(255, 255, 255, 0.8);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(131, 146, 120, 0.2);
}

/* Botão primário */
.btn-primary {
  background-color: #6f7c60;
  transition: all 0.3s ease;
}

.btn-primary:hover {
  background-color: #5a6550;
  transform: translateY(-2px);
  box-shadow: 0 10px 20px -5px rgba(111, 124, 96, 0.4);
}

/* Ícone de feature */
.feature-icon {
  background: linear-gradient(135deg, #d9e4cc 0%, #839278 100%);
}

/* Animação de fade */
.section-fade {
  opacity: 0;
  transform: translateY(30px);
  transition: opacity 0.8s ease-out, transform 0.8s ease-out;
}

.section-fade.visible {
  opacity: 1;
  transform: translateY(0);
}
```

### Layout Principal

O layout utiliza a paleta de cores verde musgo (#6f7c60) com destaques em dourado (#ffd764) e fundo claro (#f2f7f2):

```
┌─────────────────────────────────────────┐
│  Header (bg: #f2f7f2, text: #6f7c60)   │
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────────┐  ┌──────────────┐   │
│  │   Upload     │  │  Opções de   │   │
│  │   Area       │  │  Conversão   │   │
│  │ (glass-card) │  │ (glass-card) │   │
│  └──────────────┘  └──────────────┘   │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │  Pré-visualização da Imagem      │  │
│  │  (glass-card com border verde)   │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │ [btn-primary] [btn-secondary]    │  │
│  └──────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

**Elementos Visuais:**
- Fundo: #f2f7f2 (verde claro)
- Cards: glass-card com backdrop blur
- Botões: btn-primary (#6f7c60) com hover em #5a6550
- Destaques: Dourado (#ffd764) para ícones e elementos importantes
- Padrão: vine-pattern para detalhes decorativos
- Animações: section-fade para transições suaves

### Responsividade

- **Mobile (< 640px):** Layout em coluna única, botões em tela cheia
- **Tablet (640px - 1024px):** Dois painéis lado a lado
- **Desktop (> 1024px):** Layout otimizado com espaçamento generoso

---

## 💻 Componentes React

### ImageUploader
```typescript
// Props
interface ImageUploaderProps {
  onImageSelected: (file: File) => void;
  isLoading?: boolean;
}

// Funcionalidades
- Drag and drop
- Click to select
- Paste from clipboard
- Validação de arquivo
- Feedback visual
```

### ConversionOptions
```typescript
// Props
interface ConversionOptionsProps {
  selectedFormat: string;
  quality: number;
  onFormatChange: (format: string) => void;
  onQualityChange: (quality: number) => void;
}

// Funcionalidades
- Seletor de formato
- Slider de qualidade
- Recomendações
- Preview de tamanho
```

### ImagePreview
```typescript
// Props
interface ImagePreviewProps {
  originalImage: HTMLImageElement;
  convertedBlob: Blob;
  format: string;
}

// Funcionalidades
- Exibição da imagem
- Informações de arquivo
- Comparação visual
```

---

## 🔧 Hooks Customizados

### useImageConverter
```typescript
const {
  convertImage,        // Função de conversão
  isConverting,        // Estado de carregamento
  error,               // Mensagem de erro
  convertedBlob,       // Blob convertido
  conversionStats      // Estatísticas (tamanho, tempo)
} = useImageConverter();
```

### useImageValidation
```typescript
const {
  validateFile,        // Função de validação
  isValid,             // Resultado da validação
  errorMessage         // Mensagem de erro
} = useImageValidation();
```

---

## 🔄 Fluxo de Conversão

### Algoritmo de Conversão

**Para Formatos Raster (PNG, JPEG, WebP, GIF):**
```typescript
1. Carregar arquivo como Blob
2. Criar objeto URL para preview
3. Criar elemento Image e carregar
4. Criar Canvas com dimensões da imagem
5. Desenhar imagem no canvas
6. Aplicar filtros/ajustes (se necessário)
7. Exportar canvas para Blob com formato desejado
8. Gerar URL de download
9. Liberar recursos (URLs, canvas)
```

**Para SVG:**
```typescript
// Conversão SVG → Raster (PNG/JPG/WebP):
1. Carregar arquivo SVG como texto/XML
2. Renderizar SVG em Canvas usando CanvgJS ou similar
3. Exportar Canvas para formato raster desejado
4. Gerar URL de download

// Conversão Raster → SVG (Vetorização - Opcional):
1. Carregar imagem raster
2. Usar biblioteca de vetorização (Potrace.js ou similar)
3. Gerar arquivo SVG
4. Gerar URL de download
```

### Formatos de Saída

**PNG → JPEG:**
```typescript
canvas.toBlob(blob => {...}, 'image/jpeg', quality)
```

**PNG → WebP:**
```typescript
canvas.toBlob(blob => {...}, 'image/webp', quality)
```

**JPEG → PNG:**
```typescript
canvas.toBlob(blob => {...}, 'image/png')
```

---

## 📊 Requisitos Não-Funcionais

### Performance
- Conversão de imagem < 2 segundos (para imagens típicas)
- Carregamento inicial < 3 segundos
- Suporte para imagens até 50MB

### Acessibilidade (WCAG 2.1 AA)
- Contraste de cores adequado
- Labels em todos os inputs
- Navegação por teclado
- Suporte a leitores de tela

### Compatibilidade
- Chrome/Edge 90+
- Firefox 88+
- Safari 14+
- Mobile browsers modernos

### Segurança
- Sem envio de dados para servidores
- Sem cookies de rastreamento
- HTTPS recomendado (se hospedado)

---

## 🚀 Fases de Desenvolvimento

### Fase 1: MVP (Mínimo Viável)
- [x] Upload de imagem (clique)
- [x] Conversão PNG ↔ JPEG
- [x] Controle de qualidade
- [x] Download do arquivo
- [x] Interface básica responsiva

### Fase 2: Melhorias
- [ ] Drag and drop
- [ ] Suporte a WebP, GIF e SVG
- [ ] Pré-visualização em tempo real
- [ ] Histórico de conversões
- [ ] Tema escuro

### Fase 3: Recursos Avançados
- [ ] Processamento em lote
- [ ] Redimensionamento de imagens
- [ ] Filtros (brilho, contraste, saturação)
- [ ] Corte de imagem
- [ ] Vetorização de imagens (Raster → SVG)

---

## 📝 Checklist de Implementação

### Setup Inicial
- [ ] Inicializar projeto com Vite + React + TypeScript
- [ ] Configurar Tailwind CSS e shadcn/ui
- [ ] Estruturar diretórios conforme especificação
- [ ] Configurar TypeScript strict mode

### Componentes
- [ ] ImageUploader (com validação)
- [ ] FormatSelector
- [ ] QualitySlider
- [ ] ImagePreview
- [ ] DownloadButton
- [ ] ErrorBoundary
- [ ] LoadingSpinner

### Lógica
- [ ] Função de conversão de imagem
- [ ] Validação de arquivo
- [ ] Geração de URL de download
- [ ] Tratamento de erros
- [ ] Cálculo de tamanho de arquivo

### Testes
- [ ] Testar conversão PNG → JPEG
- [ ] Testar conversão JPEG → PNG
- [ ] Testar conversão para WebP
- [ ] Testar conversão para GIF
- [ ] Testar conversão SVG → PNG/JPG/WebP
- [ ] Testar validação de arquivo
- [ ] Testar responsividade
- [ ] Testar acessibilidade

### Deploy
- [ ] Build otimizado
- [ ] Testar em navegadores reais
- [ ] Verificar performance
- [ ] Deploy em servidor estático

---

## 📚 Recursos Úteis

### APIs do Navegador
- [Canvas API](https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API)
- [File API](https://developer.mozilla.org/en-US/docs/Web/API/File)
- [Blob API](https://developer.mozilla.org/en-US/docs/Web/API/Blob)
- [Image API](https://developer.mozilla.org/en-US/docs/Web/API/HTMLImageElement)

### Bibliotecas Úteis (Opcional)
- [sharp.js](https://sharp.pixelplumbing.com/) - Processamento avançado (Node.js)
- [Jimp](https://github.com/jimp-dev/jimp) - Manipulação de imagens (JS puro)
- [pica](https://github.com/nodeca/pica) - Redimensionamento de alta qualidade

### Documentação
- [React 19 Docs](https://react.dev)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)
- [Tailwind CSS Docs](https://tailwindcss.com/docs)
- [shadcn/ui Docs](https://ui.shadcn.com/)

---

## 🎓 Notas de Desenvolvimento

### Considerações Importantes

1. **Limite de Memória:** Imagens muito grandes podem consumir muita RAM. Considere avisar o usuário.

2. **Suporte de Formato:** Nem todos os navegadores suportam todos os formatos. Testar em múltiplos browsers.

3. **Qualidade de Conversão:** A qualidade depende da implementação do navegador. JPEG pode ter artefatos em qualidades muito altas.

4. **Transparência:** Ao converter PNG com transparência para JPEG, a transparência será preenchida com cor de fundo (geralmente branco).

5. **Performance:** Para imagens muito grandes, usar Web Workers pode melhorar a responsividade.

### Boas Práticas

- Sempre validar entrada do usuário
- Fornecer feedback visual durante processamento
- Usar try-catch para tratamento de erros
- Liberar recursos (URLs, canvas) após uso
- Testar com imagens de diferentes tamanhos
- Otimizar bundle size do projeto

---

## 📞 Próximos Passos

1. **Revisar esta documentação** com o time/stakeholders
2. **Criar mockups** da interface (opcional)
3. **Inicializar o projeto** com Vite
4. **Implementar componentes** conforme especificação
5. **Testar funcionalidades** em múltiplos browsers
6. **Deploy** da aplicação

---

**Versão:** 1.0  
**Data:** Julho 2026  
**Status:** Documentação Inicial - Pronto para Desenvolvimento
