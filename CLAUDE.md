# Ranking Foods

App mobile para ranquear pratos e restaurantes, começando por Juiz de Fora (MG).
O plano completo do produto está em [PLANO.md](PLANO.md). As tarefas de cada parte do roteiro ficam em `docs/partes/Pn.md`.

## Estrutura

```
apps/mobile/      App Expo (SDK 58, expo-router, TypeScript strict). Leia apps/mobile/AGENTS.md.
supabase/         Projeto Supabase: config.toml, migrations/, seed.sql, tests/ (pgTAP)
scripts/data/     Scripts de importação e limpeza de dados (OSM, Foursquare)
docs/             Decisões e tarefas por parte (docs/partes/)
.github/          CI: lint + typecheck do mobile; migrations aplicando do zero
```

Monorepo com **npm workspaces** (não use pnpm, yarn ou bun). Rode `npm install` na raiz.

## Comandos (na raiz)

```bash
npm run mobile      # expo start
npm run check       # lint + typecheck. Rode antes de dar uma tarefa como pronta.
npm run db:start    # sobe o Supabase local (precisa do Docker Desktop rodando)
npm run db:reset    # recria o banco local aplicando migrations + seed.sql
npm run db:types    # gera apps/mobile/src/lib/database.types.ts a partir do banco local
```

Para criar uma migration, crie o arquivo `supabase/migrations/<AAAAMMDDHHMMSS>_<nome>.sql` à mão.
O `supabase migration new` pode ficar esperando entrada neste ambiente.

## Convenções

- **Idioma**: textos da interface e comentários em português; nomes de código (variáveis, funções, tabelas, colunas) em inglês.
- **Rotas** em `apps/mobile/src/app/` com nomes em português, porque viram URLs (`/rankings`, `/perfil`). Componentes, hooks e utilitários ficam fora de `src/app/`.
- **Cores** só via `Colors` em `src/constants/theme.ts` (light/dark) e os componentes `ThemedText`/`ThemedView`. Nada de cor literal em tela.
- **Pacotes do mobile**: sempre `npx expo install <pkg>` dentro de `apps/mobile`, nunca `npm install <pkg>`.
- **Banco**: toda tabela nova nasce com RLS habilitado e políticas explícitas, na mesma migration. Extensões ficam no schema `extensions`.
- **Contrato Backend ↔ Mobile**: os tipos gerados por `npm run db:types`. Quem muda o schema regenera os tipos no mesmo commit.
- **Segredos**: nunca no git. O mobile só lê variáveis `EXPO_PUBLIC_*` (veja `apps/mobile/.env.example`). Chave `service_role` nunca vai para o app.

## Agentes (Maestri)

Cada agente edita apenas as suas pastas. Para mudar algo fora delas, peça ao Coordenador.

| Agente | Pode editar |
|---|---|
| Coordenador | `PLANO.md`, `CLAUDE.md`, `docs/` |
| Backend/DB | `supabase/` (exceto `supabase/tests/`), `apps/mobile/src/lib/database.types.ts` |
| Dados | `scripts/data/`, `supabase/seed.sql` |
| Mobile | `apps/mobile/` |
| QA/Revisor | `supabase/tests/`, `**/__tests__/` |

Fluxo de uma parte: o Coordenador escreve `docs/partes/Pn.md` → o Backend entrega o schema e os tipos → o Mobile consome → o QA valida → o Coordenador marca a parte como concluída no arquivo.
