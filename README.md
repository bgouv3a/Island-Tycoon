# Island Rebuild

Jogo **Simulator + Tycoon** para Roblox, desenvolvido em **Luau**.

- **Gameplay:** coleta de recursos, construção de ilhas e automação.
- **Multiplayer:** cada jogador tem sua ilha individual, com interação social entre ilhas.
- **Plataformas:** PC e mobile no lançamento; arquitetura preparada para consoles.
- **Modelo:** gratuito. Monetização futura, sem vantagens que quebrem a progressão.
- **Estilo:** low-poly, colorido e otimizado.

## Status
**Fase 1 — base técnica (sem gameplay).** Em andamento. Ver [`docs/ROADMAP.md`](docs/ROADMAP.md).

## Como rodar (desenvolvimento)
Pré-requisitos: Roblox Studio, [Rojo](https://rojo.space) 7.7.1, Wally 0.3.2, StyLua 2.6.0 e Selene 0.32.0 (versões fixadas em `docs/skills-e-ferramentas.md`).

```
wally install
rojo serve test.project.json      # abre no Studio com os testes TestEZ
```

Para verificar formatação, lint e builds, ver os comandos em [`CLAUDE.md`](CLAUDE.md) e o workflow em `.github/workflows/ci.yml`.

## Estrutura
```
src/shared   código compartilhado (configs, tipos, lógica pura)
src/server   código do servidor (serviços autoritativos)
src/client   código do cliente (interface, input, efeitos)
tests/       testes de lógica pura (só no projeto de teste)
docs/        documentação do projeto
```

## Documentação
Comece por [`docs/README.md`](docs/README.md), que é o índice e o checklist do projeto.

| Documento | Conteúdo |
|---|---|
| [`docs/GDD.md`](docs/GDD.md) | Visão e design do jogo |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Arquitetura técnica |
| [`docs/decisoes.md`](docs/decisoes.md) | Decisões do projeto |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Fases e marcos |
| [`docs/CHANGELOG.md`](docs/CHANGELOG.md) | Histórico de alterações |

Instruções para o assistente de IA estão em [`CLAUDE.md`](CLAUDE.md).
