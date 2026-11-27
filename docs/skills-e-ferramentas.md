# Skills e ferramentas — Island Rebuild

Registro de tudo o que foi instalado ou habilitado no projeto. Instalar apenas após aprovação do dono do projeto e revisão da origem.

## Skills e plugins

| Item | Tipo | Origem | Data | Uso |
|---|---|---|---|---|
| `roblox-dev` | Plugin do Claude Code | `anthropic-plugin-directory` (habilitado em `.claude/settings.local.json`) | 2026-11-24 | Skills Roblox: arquitetura, segurança, DataStore, performance, tipagem strict, testes, UI e setup |
| `find-skills` | Skill global | Pré-instalada no ambiente do usuário | 2026-11-24 | Busca de skills com `npx -y skills find <termo>` |
| `Roblox_Studio` | Servidor MCP (stdio) | `mcp.bat` do próprio Roblox Studio em `%LOCALAPPDATA%\Roblox`, registrado com `claude mcp add` pelo dono do projeto | 2026-11-25 | Ponte entre o Claude e o Studio. Verificado: conectado. Configuração em `%USERPROFILE%\.claude.json` (fora do repositório). Não usar para operar DataStore de produção |

## Subagentes do Claude Code (`.claude/agents/`)

Criados em 2026-11-26 a pedido do dono. Regras de delegação no `CLAUDE.md` (seção "Modelos e subagentes"). Nenhuma configuração global de modelo de subagente foi alterada.

| Agente | Modelo | Ferramentas | Uso |
|---|---|---|---|
| `fast-assistant` | haiku | Read, Grep, Glob, Edit, Write | Buscas, resumos, documentação, tarefas mecânicas |
| `game-developer` | sonnet | Todas (herdadas) | Implementação Luau baixa/média, bugs, testes, UI |
| `world-builder` | sonnet | Todas (herdadas, inclui Roblox Studio MCP) | Cenários low-poly no Studio |
| `quality-reviewer` | sonnet | Read, Grep, Glob, Bash e MCP do Studio para Play, console e testes | Revisão e testes; não edita arquivos |

## Ferramentas (aprovadas e fixadas)

| Ferramenta | Versão | Função | Verificação | Onde está configurada |
|---|---|---|---|---|
| Rojo | 7.7.1 | Sincronizar `src/` com o Studio e gerar builds | sha256 no CI (linux) | `default.project.json`, `test.project.json`, `ci.yml` |
| Wally | 0.3.2 | Gerenciar pacotes Luau | sha256 no CI (linux) | `wally.toml`, `wally.lock` |
| StyLua | 2.6.0 | Formatação | sha256 no CI (linux) | `stylua.toml`, `ci.yml` |
| Selene | 0.32.0 | Lint | sha256 no CI (linux) | `selene.toml`, `ci.yml` |
| Git e GitHub | — | Controle de versão e CI | — | `.gitignore`, `.github/workflows/ci.yml` |
| GitHub Actions | — | CI | `actions/checkout` fixado por SHA (`11d5960a…`, tag v4) | `.github/workflows/ci.yml` |

### sha256 usados no CI (arquivos linux x86_64)
- Rojo 7.7.1: `00feb4fa0829a1dd72b49df2639da519a352bfe13cadcd83969e2ba2bb5693c4`
- StyLua 2.6.0: `a485f72bbfa22e4642e77a84b5edc2611a5cab7477b34e2e709dd8f78e919895`
- Selene 0.32.0: `d3773393578580074386e69337d35b7acddfbaa9fc38964c07fa3e28436ade9b`
- Wally 0.3.2: `21fdbb53dfee397fd21ca7fdd208db65cff0f87f0fd045cdb594b951981bd73f`

## Assets externos

| Asset | ID | Origem | Uso |
|---|---|---|---|
| Som "Wood Chopping Exterior Single Hits 27 (SFX)" | 9120809592 | ProSoundEffects (Creator Store, gratuito, parceira oficial da Roblox) | Coleta (`Config/Audio`) |
| Som "Gavel Hit Wood Mallet Hit Wood Light Impacts (SFX)" | 9125573847 | ProSoundEffects (idem) | Construção (`Config/Audio`) |

Modelos, texturas de partículas (`rbxasset://`, internas do Roblox) e ícones são gerados por código; nenhum modelo ou script de terceiros foi inserido.

## Dependências Luau (Wally)

| Pacote | Versão | Realm | Uso | Fonte verificada |
|---|---|---|---|---|
| `lm-loleris/profilestore` | =1.0.3 | server | Persistência (apenas via `DataService`) | Índice do Wally + revisão do código instalado |
| `roblox/testez` | =0.4.1 | dev | Testes de lógica pura | Índice do Wally |

Regras:
- Versões **exatas** (`=`). Atualização só com aprovação, teste no Studio e registro em `decisoes.md`.
- Nenhuma dependência nova sem aprovação, conforme o princípio de "somente o necessário".

## Ferramentas avaliadas e não usadas
- **Aftman / Rokit** (gerenciadores de ferramentas): não adotados. O CI instala cada ferramenta por URL fixada e sha256, o que dispensa um gerenciador.
- **Luau CLI (`luau-analyze`) 0.748**: instalado a partir do asset oficial `luau-windows.zip` do release `0.748` (luau-lang/luau), com sha256 `072b06454fb0fa5c355a6aaae361a01c4d35d120a37d0fe4fd1a880a9ffebeab` verificado. Uso local. Ainda não no CI, porque faltam as definições de tipo do Roblox (ver P-006).
- **Lune** (execução de Luau fora do Roblox): não avaliado, pois exige aprovação.

## Regras
- Antes de instalar qualquer skill, revisar a origem e pedir aval ao dono do projeto.
- Nunca registrar chaves de API, tokens ou senhas nesta página.
