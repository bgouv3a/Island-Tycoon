# Changelog — Island Rebuild

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

## [Não lançado]

### 2026-11-24 — Fase 1: base técnica (sem gameplay)
#### Adicionado
- **Projeto Rojo:** `default.project.json` (produção) e `test.project.json` (teste, com testes e TestEZ).
- **Dependências Wally** com versão exata: `lm-loleris/profilestore =1.0.3` e `roblox/testez =0.4.1`. `wally.lock` gerado.
- **Servidor:** `init.server.luau` (bootstrap), `Services/NetService.luau` (rate limit, validação e handler de remotes) e `Services/DataService.luau` (única camada que usa o ProfileStore).
- **Cliente:** `init.client.luau` (bootstrap) e `Input/InputModeController.luau` (toque, teclado/mouse, gamepad).
- **Compartilhado:**
  - `Config/Persistence.luau`: nome do DataStore, sufixo do Studio e versão do schema.
  - `Types/PlayerData.luau`: formato dos dados do jogador.
  - `Logic/SchemaMigrator.luau`: status de versão e migrações.
  - `Logic/RateLimiter.luau`: limitador por balde de fichas.
  - `Logic/Validate.luau`: validadores de argumentos (número finito, inteiro, string, booleano).
  - `Logic/InputMode.luau`: classificação de modo de entrada.
- **Testes TestEZ** em `tests/Logic/` (SchemaMigrator, RateLimiter, Validate, InputMode) e runner em `tests/Runner.server.luau`.
- **Qualidade:** `stylua.toml`, `selene.toml` (`std = "roblox"`), `.gitignore`.
- **CI:** `.github/workflows/ci.yml` com verificação de sha256 das ferramentas, `wally install`, `stylua --check`, `selene` e os dois builds do Rojo.
- **Documentação:** decisões D-005 a D-022 em `decisoes.md`; arquitetura atualizada com a aprovação; GDD com plataformas e modelo de negócio; roadmap com o checklist da Fase 1.

#### Verificado (localmente, com as versões fixadas)
- `wally install`: 2 pacotes baixados.
- `stylua --check src tests`: sem diferenças.
- `selene src tests`: 0 erros, 0 avisos.
- `rojo build default.project.json`: gerado. Confirmado que não contém `tests/` nem TestEZ.
- `rojo build test.project.json`: gerado.
- Revisão do código do ProfileStore 1.0.3: sem `loadstring`, sem chamadas HTTP arbitrárias, sem `require` externo.

#### Verificado (checagem `--!strict`, luau-analyze 0.748 oficial, sha256 conferido)
- `src/shared/Logic`, `src/shared/Config` e `src/shared/Types`: sem erros.
- `src/server` e `src/client`: restam apenas erros de ambiente (globais e tipos do Roblox ausentes no analisador puro). Ver P-006.
- Corrigido: `deepCopy` no `DataService` (erro real de tipagem, ver P-008).

#### Não verificado (pendente)
- Testes TestEZ e comportamento do DataService no Studio (ver checklist em `ROADMAP.md`).
- Checagem completa de `--!strict` no servidor e cliente, que depende das definições de tipo do Roblox (P-006).
- Push para o GitHub (sem URL de repositório configurada).

#### Alterado
- `CLAUDE.md`, `README.md`, `docs/README.md`, `docs/GDD.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `docs/decisoes.md`, `docs/problemas-e-aprendizados.md`, `docs/skills-e-ferramentas.md`: atualizados com as decisões aprovadas.

#### Não removido
- Nenhum arquivo existente foi excluído ou substituído. A pasta `.claude/` foi mantida.

### 2026-11-24 — Documentação inicial e proposta de arquitetura
#### Adicionado
- `CLAUDE.md`, `README.md`, `docs/` com GDD, ARCHITECTURE, ROADMAP, CHANGELOG, decisões, problemas e skills.

#### Observado
- Repositório Git vazio: sem commits e sem remote.
- Configuração existente: `.claude/settings.local.json`, com o plugin `roblox-dev` habilitado.
