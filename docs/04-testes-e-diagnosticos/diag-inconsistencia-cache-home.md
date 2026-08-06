# Análise Tecnológica: Inconsistência de Cache entre a Tela Home e "Todos os Cursos"

## 1. Descrição do Problema
Ao publicar um novo curso ou atualizar o status de um curso existente (ex: de `COMING_SOON` para `PUBLISHED`), a atualização é refletida na listagem do catálogo **"Todos os Cursos"**, mas a **Tela Home** (carrossel / cards de cursos em destaque) continua exibindo o estado antigo armazenado em cache.

---

## 2. Causa Raiz Identificada

### A. Chaves de Cache Desconectadas no React Query (`useCourses.ts`)
O React Query gerencia o cache de cada consulta de forma isolada através de `queryKey`s distintas:
- **Tela Home**: Utiliza a função `useFeaturedCourses()`, cuja `queryKey` é `['courses', 'featured']`.
- **Todos os Cursos**: Utiliza a função `useCourses()`, cuja `queryKey` é `['courses']`.

Como as duas chaves são diferentes no React Query, revalidar ou atualizar uma **não atualiza automaticamente a outra**.

### B. Configuração de TTL (`staleTime`) Longa
Ambas as queries possuem a seguinte configuração:
```typescript
staleTime: 1000 * 60 * 60 * 24, // 24 horas
refetchOnMount: false,
refetchOnReconnect: true,
```
- Como `staleTime` está configurado para **24 horas** e `refetchOnMount` está como `false`, quando o usuário retorna à Tela Home, o React Query reutiliza os dados em memória salvos na chave `['courses', 'featured']` sem realizar nova requisição ao servidor durante 24h.

### C. Camada Cache-First do SDK do Firestore (`courseService.ts`)
Tanto `getCourses()` quanto `getFeaturedCourses()` utilizam `getDocsFromCache(q)` antes de consultar o servidor (`getDocsFromServer`). Caso o cache interno do SDK do Firestore já possua documentos retornados da query anterior, ele responde instantaneamente via cache local.

---

## 3. Soluções Propostas para Implementação Futura

### Opção 1: Invalidação Cruzada no `useFocusEffect` ou Pull-to-Refresh
No evento de foco da Tela Home e da Tela de Catálogo, invalidar a hierarquia pai da chave de cursos:
```typescript
// Ao invalidar a raiz ['courses'], o React Query marca como stale tanto ['courses'] quanto ['courses', 'featured']
queryClient.invalidateQueries({ queryKey: ['courses'] });
```

### Opção 2: Reduzir `staleTime` dos Cursos em Destaque na Home
Reduzir o `staleTime` de `useFeaturedCourses` (ex: de 24h para 5 ou 15 minutos) ou permitir `refetchOnMount: true` para que a Home verifique novos destaques ao navegar de volta.

### Opção 3: Invalidação Global de Cache pós-Publicação (Admin/Trigger)
Implementar um mecanismo de invalidação por timestamp de última atualização do catálogo no Firestore (ex: `system_configs/courses_last_updated`), fazendo com que o app compare a versão do cache com o servidor ao abrir a Home.

---

*Documento gerado para análise posterior da equipe de desenvolvimento.*
