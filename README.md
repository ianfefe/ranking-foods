# Ranking Foods

App mobile para descobrir os melhores pratos e restaurantes de Juiz de Fora, avaliados pela comunidade.

- Plano do produto: [PLANO.md](PLANO.md)
- Convenções e comandos: [CLAUDE.md](CLAUDE.md)

## Primeiros passos

Requisitos: Node 20+, Docker Desktop (para o Supabase local) e o app **Expo Go** no celular.

```bash
npm install
npm run mobile        # abre o Expo; escaneie o QR code com o Expo Go
```

Banco local (opcional na P0):

```bash
npm run db:start      # mostra a API URL e a chave anon
cp apps/mobile/.env.example apps/mobile/.env.local   # e preencha a chave
```
