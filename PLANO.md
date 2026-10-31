# Ranking Foods — Plano do Produto

> App mobile para descobrir restaurantes e, principalmente, **os melhores pratos** de cada lugar, com notas, preços e fotos dados por uma comunidade.
> Cidade de lançamento: **Juiz de Fora (MG)**. Nome do app: *a definir*.

---

## 1. Visão e diferencial

O Google Maps avalia **o lugar**. O Ranking Foods avalia **o que você come**.

- "Onde está o melhor hambúrguer de Juiz de Fora?" → um ranking de **pratos**, não de restaurantes.
- Cada restaurante mostra seus pratos ranqueados, com preço atual informado pela comunidade.
- O local também é avaliado por critérios separados: atendimento, ambiente, custo-benefício e limpeza.
- Uma comunidade com reputação: quem avalia bem e com frequência tem mais peso.

## 2. Decisões tomadas

| Tema | Decisão |
|---|---|
| Objetivo | Produto real (lojas, usuários, receita) |
| Mobile | React Native + Expo (TypeScript) |
| Backend | Supabase (Postgres + PostGIS, Auth, Storage, Edge Functions) |
| Dados dos restaurantes | Híbrido: base importada + a comunidade completa |
| Avaliação | Nota por prato, critérios do local, preço e rankings |
| Antifraude | Peso por reputação + peso extra para avaliação com foto (a foto **não** é obrigatória) |
| Social | Seguir pessoas, listas, reações/comentários, gamificação (**fase 2**) |
| Receita | Painel do restaurante + destaque pago (**fase 2**) |
| Lançamento | Juiz de Fora primeiro |
| Equipe | Solo/amigos, orquestrando agentes com o Maestri |
| Ritmo | Por partes: MVP enxuto primeiro, com a fase 2 já planejada |

## 3. Stack

**Mobile (`apps/mobile`)**
- Expo SDK + **expo-router** (navegação por arquivos) + TypeScript
- **TanStack Query** para dados do servidor e **Zustand** para estado local leve
- `react-native-maps` (Apple Maps no iOS, Google Maps no Android)
- `expo-location`, `expo-image-picker`, `expo-image` (cache de imagens)
- Login: Apple, Google e e-mail (Apple exige "Sign in with Apple" quando há login social)
- **EAS Build/Submit** para gerar e publicar os builds, e **EAS Update** para atualizações OTA

**Backend (`supabase/`)**
- Postgres + **PostGIS** (busca "perto de mim" com `ST_DWithin`)
- **Row Level Security** em todas as tabelas
- **Storage** para as fotos (redimensionadas antes do upload)
- **Edge Functions** para importação de dados, recálculo de reputação e moderação
- **pg_cron** para atualizar os rankings (materialized views)
- Busca textual: `pg_trgm` + `unaccent` (para "feijoada" encontrar "Feijoáda da Vó")

**Web (fase 2, `apps/web`)**: Next.js para o painel do restaurante e o admin de moderação.

**Qualidade**: ESLint, Prettier, Vitest/Jest, testes de RLS com pgTAP e GitHub Actions.

## 4. Fonte de dados dos restaurantes

⚠️ **Cuidado com o Google Places:** os termos do Google Maps Platform **não permitem armazenar** os dados do Places no seu banco (só o `place_id` pode ser guardado por tempo indefinido). Por isso, usar o Google como base "importada" é arriscado. Revise os termos antes de decidir.

**Recomendação:**
1. **Base**: OpenStreetMap (Overpass API, licença ODbL, exige atribuição) + **Foursquare Open Source Places** (licença Apache 2.0) filtrados para Juiz de Fora. Os dois permitem armazenar os dados.
2. **Curadoria manual**: revisar a lista, remover lugares fechados e adicionar os que faltam (é um trabalho viável para uma única cidade).
3. **Comunidade**: os usuários sugerem restaurantes novos e adicionam pratos e preços; tudo entra como `pendente` até ser aprovado (ou é aprovado automaticamente para usuários de reputação alta).
4. **Opcional**: guardar o `place_id` do Google para um botão "abrir no Google Maps/rotas".

## 5. Sistema de notas e ranking

### 5.1 Peso de cada avaliação
```
peso = fator_reputação × fator_foto
fator_reputação ∈ [0.5, 2.0]   (conta nova = 1.0)
fator_foto      = 1.3 se tem foto, senão 1.0
```
A **reputação** sobe com: tempo de conta, quantidade de avaliações, votos "útil" recebidos e fotos aprovadas.
Ela cai com: denúncias procedentes e padrões suspeitos (muitas notas 5 ou 1 seguidas, várias contas no mesmo aparelho etc.).

### 5.2 Nota do prato (média bayesiana)
Evita que um prato com uma única nota 5 fique no topo do ranking.
```
nota = (C × m + Σ pesoᵢ × notaᵢ) / (C + Σ pesoᵢ)
m = média global da categoria (ex.: todos os hambúrgueres de JF)
C = confiança mínima (começar com 5 e ajustar)
```
Na fase 2, entra também um **decaimento temporal**: avaliações recentes pesam mais (porque o cozinheiro muda e a receita muda).

### 5.3 Nota do restaurante
- Uma nota para cada critério: atendimento, ambiente, custo-benefício e limpeza (média bayesiana).
- Nota geral = combinação das notas dos critérios com a média dos seus **pratos mais bem avaliados**.

### 5.4 Preço
- Cada avaliação de prato pode informar o **preço pago** e a data.
- O preço exibido é a **mediana dos últimos 90 dias**.
- A faixa do restaurante ($–$$$$) é calculada a partir do gasto médio informado por pessoa.

### 5.5 Rankings
- Top pratos **por categoria** (hambúrguer, pizza, açaí, feijoada, sushi…)
- Top restaurantes **por tipo de culinária** e **por bairro**
- "Perto de mim" (ordenado pela nota, dentro de um raio)
- Mínimo de N avaliações para aparecer no ranking (ex.: 3)

## 6. Modelo de dados (MVP)

```
profiles          (id → auth.users, username, avatar_url, reputation, created_at)
restaurants       (id, name, slug, location geography(Point), address, neighborhood,
                   cuisines text[], price_level, hours jsonb, phone, instagram,
                   source, source_id, google_place_id, status, created_by)
dish_categories   (id, name, slug, icon)
dishes            (id, restaurant_id, category_id, name, description, status, created_by)
dish_reviews      (id, dish_id, user_id, rating numeric(2,1), price_paid_cents,
                   text, has_photo, weight, created_at, updated_at)
                   UNIQUE(dish_id, user_id)  -- uma avaliação por prato (pode ser editada)
restaurant_reviews(id, restaurant_id, user_id, service, ambience, value,
                   cleanliness, text, weight, created_at)
review_photos     (id, review_type, review_id, storage_path, status)
review_votes      (review_type, review_id, user_id, helpful bool)
reports           (id, reporter_id, target_type, target_id, reason, status, resolved_by)
user_blocks       (blocker_id, blocked_id)

-- materialized views, atualizadas via pg_cron:
dish_scores, restaurant_scores, category_rankings
```

**Fase 2** acrescenta: `follows`, `lists`, `list_items`, `comments`, `reactions`, `badges`, `user_badges`, `xp_events`, `restaurant_claims`, `owner_replies`, `sponsored_placements`, `notifications`.

## 7. Fase 1 — MVP enxuto

**Meta:** um usuário de Juiz de Fora abre o app, encontra o melhor prato do tipo que quer, vê o preço e avalia o que comeu em menos de 30 segundos.

### Telas
1. **Onboarding + login** (Apple, Google, e-mail) e permissão de localização
2. **Explorar**: mapa + lista com filtros (culinária, preço, distância, nota, "aberto agora")
3. **Busca**: por restaurante **ou por prato** ("parmegiana" → ranking de parmegianas)
4. **Restaurante**: notas por critério, pratos ranqueados, faixa de preço, fotos, horário, rotas
5. **Prato**: nota, preço atual, fotos e avaliações (ordenadas por "mais úteis")
6. **Avaliar** (fluxo rápido): escolher ou adicionar o prato → estrelas → preço (opcional) → foto (opcional, com o aviso "avaliações com foto valem mais") → texto (opcional)
7. **Rankings**: top por categoria e por bairro em JF
8. **Perfil**: minhas avaliações e reputação (só o número, sem gamificação)
9. **Sugerir restaurante** (entra como pendente)

### Obrigatório para ser aprovado nas lojas e cumprir a LGPD
Mesmo que a moderação completa fique para a fase 2, **a Apple exige isto em apps com conteúdo de usuários** (diretriz 1.2):
- Botão **denunciar** em avaliações, fotos e perfis
- **Bloquear** usuário
- **Excluir conta** dentro do app (exigência da Apple e da LGPD)
- Termos de uso + política de privacidade (localização, fotos, dados pessoais)
- Admin mínimo para tratar as denúncias (no começo pode ser o Supabase Studio + uma view `reports_pending`)

### Fora do MVP (de propósito)
Feed social, seguidores, listas, comentários, gamificação, painel do restaurante, destaque pago, notificações push e outras cidades.

## 8. Roteiro por partes (Fase 1)

Cada parte termina com algo **funcionando e testável**. Não há prazo, a ordem é o que importa.

| Parte | Entrega | Pronto quando… |
|---|---|---|
| **P0 – Fundação** | Monorepo (`apps/mobile`, `supabase/`, `docs/`), Expo + expo-router + TS, projeto Supabase local e remoto, lint/CI, `CLAUDE.md` com as convenções | O app abre em um simulador/aparelho e o CI passa |
| **P1 – Dados** | Migrations do schema, PostGIS, RLS, seed de categorias, script de importação de OSM + Foursquare para JF | Mais de 300 restaurantes de JF no banco com localização correta |
| **P2 – Explorar (só leitura)** | Mapa, lista, filtros, busca, telas de restaurante e de prato | Dá para navegar por JF e encontrar restaurantes sem estar logado |
| **P3 – Avaliar** | Login, fluxo de avaliação, upload de foto, cálculo de peso e nota | Uma avaliação nova muda a nota do prato corretamente (com teste) |
| **P4 – Rankings + perfil** | Materialized views + pg_cron, tela de rankings, perfil, reputação v1 | Os rankings por categoria e bairro aparecem e são atualizados |
| **P5 – Confiança e lojas** | Denunciar, bloquear, excluir conta, termos/privacidade, revisão de RLS, Sentry, analytics | Checklist da App Store/Play cumprido; build beta no TestFlight e no teste interno da Play |
| **P6 – Lançamento em JF** | Conteúdo inicial: você + amigos avaliam cerca de 150 pratos em 40 lugares; ícone, screenshots, página na loja | Publicado nas lojas, com 20+ usuários reais ativos |

### O problema do "app vazio" (cold start)
- **Você e os amigos são os primeiros críticos**: avaliem os lugares que já frequentam antes de lançar.
- Comece por **5–6 categorias "de briga"** em JF (hambúrguer, pizza, açaí, pastel, parmegiana, sushi) e gere rankings que dão vontade de compartilhar.
- Convide perfis de comida locais do Instagram para o beta.
- Crie um card compartilhável "Top 5 hambúrgueres de JF" para os stories (marketing gratuito).

## 9. Fase 2 — Comunidade e receita

Começa assim que o MVP estiver no ar e com uso real. A ordem sugerida está abaixo.

**2A – Social**
- Seguir pessoas + **feed** com as avaliações de quem você segue
- **Listas**: "quero ir", "favoritos" e listas públicas compartilháveis ("Melhores botecos do Centro")
- **Reações** e **comentários** nas avaliações
- Notificações push (Expo Notifications): novo seguidor, curtida, comentário

**2B – Gamificação**
- XP por avaliar, adicionar foto, receber "útil" e adicionar um prato novo
- **Níveis** (Provador → Crítico → Chef → Lenda de JF), integrados à reputação
- **Selos** por categoria ("Rei do Hambúrguer": 20 hambúrgueres avaliados) e por exploração ("10 bairros")
- Ranking mensal de críticos da cidade
- ⚠️ A gamificação **não pode** premiar quantidade sem qualidade: o XP depende dos votos "útil" e das fotos aprovadas.

**2C – Painel do restaurante (receita 1)** — web em Next.js
- **Reivindicar página** (verificação por telefone/e-mail oficial do restaurante ou documento)
- Editar informações, cardápio e fotos oficiais
- **Responder avaliações** publicamente
- Estatísticas: visualizações, posição nos rankings, pratos mais bem avaliados, comparação com o bairro
- Plano gratuito (reivindicar + responder) e plano pago (estatísticas + destaque)

**2D – Destaque pago (receita 2)**
- Posição patrocinada em buscas e listas, **sempre com a etiqueta "Patrocinado"**
- **Nunca** altera a nota nem a posição no ranking orgânico (é isso que dá credibilidade ao produto)
- Cobrança B2B fora do app (Mercado Pago, Stripe ou Asaas), sem passar pelas compras in-app

**2E – Moderação com IA**
- Triagem automática de denúncias e textos (ofensas, spam, conteúdo fora do tema) com um LLM
- Detecção de fotos impróprias
- Fila de revisão humana no admin web

## 10. Fase 3 — Ideias para depois
- Selo de "visita verificada" por proximidade do GPS (opcional, bônus de peso)
- Decaimento temporal das notas e alertas de "o prato piorou"
- Recomendações personalizadas ("você curte X, experimente Y")
- Expansão para cidades vizinhas e capitais (Belo Horizonte, Rio)
- Integração com delivery/reservas
- Assinatura premium para usuários (se fizer sentido)

## 11. Orquestração com o Maestri

Regra de ouro: **cada agente é dono de pastas específicas**, para que dois agentes nunca editem o mesmo arquivo. Este `PLANO.md` + `docs/` + `CLAUDE.md` são o contexto compartilhado.

| Agente | Responsabilidade | Pastas que pode editar |
|---|---|---|
| **Coordenador/Arquiteto** | Mantém o plano, quebra as partes em tarefas, define contratos (tipos/API), revisa e integra | `PLANO.md`, `docs/`, `CLAUDE.md` |
| **Backend/DB** | Migrations, RLS, funções SQL, Edge Functions, cálculo de notas | `supabase/` |
| **Dados** | Importação de OSM/Foursquare, limpeza, seeds | `scripts/data/`, `supabase/seed/` |
| **Mobile** | Telas, navegação, componentes, integração com o Supabase | `apps/mobile/` |
| **QA/Revisor** | Testes, revisão de segurança (RLS!), checklist das lojas | `**/__tests__/`, `supabase/tests/` |

Fluxo sugerido por parte:
1. O Coordenador escreve as tarefas da parte em `docs/partes/Pn.md`.
2. Os tipos gerados pelo Supabase (`supabase gen types`) são o **contrato** entre o Backend e o Mobile.
3. O Backend entrega primeiro, depois o Mobile consome. O QA valida no fim de cada parte.
4. Um commit/PR por tarefa, revisado pelo Coordenador.

## 12. Custos estimados (MVP)
| Item | Custo |
|---|---|
| Apple Developer | US$ 99/ano |
| Google Play | US$ 25 (uma vez) |
| Supabase | Grátis no desenvolvimento → Pro (US$ 25/mês) no lançamento |
| Expo EAS | O plano grátis costuma bastar no início |
| Mapas | SDKs nativos do Apple/Google Maps (verificar a cota do Android) |
| Domínio + e-mail | ~R$ 50–100/ano |

## 13. Métricas de sucesso
- **Ativação**: % de usuários novos que fazem a primeira avaliação em até 7 dias
- **Conteúdo**: avaliações de pratos por semana; % com foto
- **Utilidade**: buscas que terminam em abrir a página de um restaurante ou as rotas
- **Retenção**: usuários ativos na semana 4
- **Cobertura**: % dos restaurantes de JF com 3+ avaliações

## 14. Riscos
| Risco | Mitigação |
|---|---|
| App vazio no lançamento | Uma cidade só, conteúdo inicial próprio, categorias "de briga" |
| Avaliações falsas | Peso por reputação + foto, média bayesiana, denúncias |
| Termos de API de mapas | Base OSM/Foursquare, Google só com `place_id` |
| LGPD | Consentimento claro, exclusão de conta, mínimo de dados, localização só durante o uso |
| Reprovação nas lojas | Denunciar/bloquear/excluir conta já no MVP |
| Restaurante insatisfeito | Direito de resposta (fase 2) e política clara de moderação |
| Escopo crescer demais | Seguir as partes; tudo que for novo vai para a fase 2/3 |

## 15. Perguntas em aberto
- Nome e identidade visual do app
- Nota de 1–5 com meia estrela ou de 1–10?
- Avaliar sem estar logado? (Recomendação: **não**, mas navegar sem login sim)
- Quem modera no começo: só você, ou alguns amigos como moderadores?
- Estrutura jurídica antes de cobrar restaurantes (MEI/ME)
