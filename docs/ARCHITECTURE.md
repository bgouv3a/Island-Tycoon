# Arquitetura técnica — Island Rebuild

> Status: **aprovada** em 2026-11-24 (ver `decisoes.md`, D-005 a D-022). Mudanças exigem aprovação e registro em `decisoes.md`.

## 1. Stack
| Item | Escolha | Versão | Observação |
|---|---|---|---|
| Linguagem | Luau em modo `--!strict` | — | Todo arquivo `.luau` começa com `--!strict` |
| Engine | Roblox Studio | — | — |
| Sincronização | Rojo | 7.7.1 | Código no repositório, Studio como visualizador |
| Pacotes | Wally | 0.3.2 | Somente ProfileStore (runtime) e TestEZ (desenvolvimento) |
| Persistência | ProfileStore (`lm-loleris/profilestore`) | =1.0.3 | Acessado somente pelo `DataService` |
| Testes | TestEZ (`roblox/testez`) | =0.4.1 | Somente lógica pura, dentro do Studio |
| Formatação | StyLua | 2.6.0 | Configuração em `stylua.toml` |
| Lint | Selene | 0.32.0 | `std = "roblox"`. Globais do TestEZ liberados nos specs |
| CI | GitHub Actions | — | Ferramentas com sha256 verificado |
| Controle de versão | Git e GitHub | — | — |

Versões fixadas em `wally.toml` (com `=`) e no `ci.yml`. O `wally.lock` é versionado.

## 2. Layout do repositório
```
IslandRebuild/
├── CLAUDE.md                  # regras para o assistente de IA
├── README.md
├── default.project.json       # build de produção (Rojo)
├── test.project.json          # build de teste no Studio (inclui testes e TestEZ)
├── wally.toml / wally.lock    # dependências fixadas
├── stylua.toml / selene.toml  # formatação e lint
├── .github/workflows/ci.yml   # formatação, lint e builds
├── docs/                      # documentação (memória do projeto)
├── src/
│   ├── shared/                # → ReplicatedStorage/Shared (ambos os lados)
│   │   ├── Config/            # números e nomes de configuração (Persistence)
│   │   ├── Types/             # tipos compartilhados (PlayerData)
│   │   └── Logic/             # lógica pura, sem serviços do Roblox (testável)
│   ├── server/                # → ServerScriptService/Server (somente servidor)
│   │   ├── init.server.luau   # bootstrap: NetService → DataService
│   │   └── Services/          # NetService, DataService
│   └── client/                # → StarterPlayerScripts/Client (somente cliente)
│       ├── init.client.luau   # bootstrap do cliente
│       └── Input/             # InputModeController
├── tests/                     # → ServerScriptService/Tests (só no test.project.json)
│   ├── Runner.server.luau
│   └── Logic/*.spec.luau
├── Packages/                  # gerado pelo Wally (não versionado)
├── ServerPackages/            # gerado pelo Wally: ProfileStore (não versionado)
└── DevPackages/               # gerado pelo Wally: TestEZ (não versionado)
```

Regras de dependência:
- `shared` não depende de `server` nem de `client`.
- `client` não acessa `ServerScriptService` nem `ServerPackages`.
- Código de `server` nunca é replicado.
- `Logic` não acessa serviços do Roblox, para que os testes rodem sem o jogo.

## 3. Bootstrap
- **Servidor** (`src/server/init.server.luau`): inicia `NetService` e depois `DataService`. Novos serviços entram aqui, e não em outros scripts.
- **Cliente** (`src/client/init.client.luau`): inicia `InputModeController`.

## 4. Serviços do servidor
### 4.1 DataService (base da Fase 1)
Única camada que conversa com o ProfileStore. Outros serviços usam:

| Função | Uso |
|---|---|
| `DataService.GetData(player)` | Leitura dos dados, ou `nil` se não carregados |
| `DataService.Mutate(player, fn)` | Única forma de alterar dados. Retorna `false` se o perfil não estiver ativo |
| `DataService.IsLoaded(player)` | Verifica se o perfil está carregado |
| `DataService.OnLoaded(fn)` | Callback quando o perfil de um jogador é carregado |

Comportamento:
- **Lock de sessão:** a sessão é iniciada com `StartSessionAsync`. Se o jogador sair durante o carregamento, a tentativa é cancelada.
- **Versão do schema:** antes de qualquer alteração, o status é verificado (`SchemaMigrator.GetStatus`):
  - `Current`: carrega normalmente.
  - `NeedsMigration`: migra uma **cópia**. Se falhar, libera a sessão sem gravar nada de parcial e expulsa o jogador.
  - `TooNew` ou `Invalid`: não altera os dados, libera a sessão e expulsa o jogador com mensagem de suporte.
- **Falha ao carregar:** o jogador é expulso com mensagem de nova tentativa. Nenhum dado padrão é criado por cima de dados existentes.
- **Sessão roubada:** se o perfil for assumido em outro servidor, o jogador é expulso.
- **Saída:** `PlayerRemoving` chama `EndSession`, que grava e libera o lock.
- **Fechamento do servidor:** o ProfileStore registra o próprio `game:BindToClose` e libera todos os perfis. O `DataService` não duplica essa lógica.
- **Ambiente:** no Studio usa `IslandRebuild_PlayerData_Studio`. Nunca usa `ProfileStore.Mock` em produção.

### 4.2 NetService (base da Fase 1)
Ponto único de entrada de RemoteEvents. Cada remote passa, nesta ordem, por:
1. **Rate limit** por jogador e por remote (balde de fichas, `RateLimiter`).
2. **Validação** dos argumentos (`Validate` e validadores específicos do remote).
3. **Handler** do sistema, que só roda se as duas etapas anteriores passarem.

Os remotes ficam em `ReplicatedStorage/Remotes`, criados pelo servidor.

### 4.3 Serviços previstos (fases seguintes, sem implementação ainda)
| Serviço | Fase | Responsabilidade |
|---|---|---|
| `EconomyService` | 2 | Moedas. Única fonte do saldo. Registra transações |
| `InventoryService` | 2 | Itens do jogador. Limite de slots |
| `ResourceService` | 2 | Nós de coleta: cooldown, respawn, alcance |
| `IslandService` | 3 | Atribui um lote de ilha a cada jogador |
| `BuildService` | 3 | Valida e aplica colocação: custo, propriedade, área e colisão |
| `AutomationService` | 4 | Produção das máquinas (ver seção 7) |
| `SocialService` | 6 | Visitas e permissões entre ilhas |

## 5. Cliente
- Controladores apenas para **interface, input e efeitos visuais**.
- **Modo de entrada:** `InputModeController` detecta `Touch`, `KeyboardMouse` ou `Gamepad` (classificação pura em `Logic/InputMode`). A interface reage ao modo, e não à plataforma, para que um futuro suporte a console use o mesmo caminho.
- **Interface:** layouts com escala relativa (`Scale`, não `Offset`) para PC, mobile e futuras telas de console. Detalhes na Fase 2.
- Efeitos locais (animação, partículas) podem começar antes da confirmação do servidor. O estado final sempre vem do servidor.

## 6. Comunicação cliente ↔ servidor
- O cliente envia **intenções** (ex.: "quero coletar o nó X"), nunca resultados.
- Todo argumento é validado: tipo, faixa, valor finito (sem NaN ou infinito), tamanho de string e existência do objeto.
- Rate limit por jogador e remote. Acima do limite, a chamada é ignorada.
- Dados enviados ao cliente são o mínimo necessário. O perfil completo nunca é replicado.

## 7. Automação *(aprovada, implementação na Fase 4)*
- **Um único sistema centralizado** (`AutomationService`), que não cria um loop por máquina.
- Cada máquina tem seu **intervalo próprio** de produção. O sistema guarda o horário da próxima produção de cada máquina e processa apenas as que venceram (agendamento por fila de prioridade).
- O cálculo do que produzir fica em `Logic/` (puro, testável), e o servidor aplica o resultado.
- Orçamento de máquinas ativas por ilha, em `Config`.

## 8. Persistência — resumo
- Uma chave por jogador: `Player_<UserId>`, em um DataStore por ambiente.
- Lock de sessão, salvamento automático pelo ProfileStore, `EndSession` ao sair e salvamento no fechamento do servidor.
- Versão do schema em `PlayerData.SchemaVersion` (atual: 1). Mudar o schema exige: incrementar `Persistence.SchemaVersion`, registrar a migração em `DataService` (`MIGRATIONS`) e adicionar teste em `tests/Logic`.

## 9. Ilhas — decisão aprovada (D-006)
- **Lotes individuais no mesmo servidor.** Cada jogador tem uma ilha própria dentro do mapa compartilhado.
- Visitas e interações entre jogadores ficam previstas na arquitetura, sem implementação antes da Fase 6.
- O limite de jogadores por servidor é **definido por testes de desempenho**. Por isso, o código não assume um número fixo: limites vêm de `Config`.
- `StreamingEnabled` será avaliado na Fase 3, com o layout real das ilhas.

## 10. Desempenho
- Sem `while true do` por objeto. Eventos e agendamento centralizado.
- Conexões de eventos desconectadas quando o objeto for destruído.
- Pool de objetos para efeitos e itens frequentes (Fase 2+).
- Orçamento de instâncias por ilha (máquinas, itens, partículas), em `Config`.

## 11. Testes e qualidade
- **Lógica pura** (`src/shared/Logic`): testes TestEZ em `tests/Logic/*.spec.luau`, rodados no Studio com `test.project.json`.
- **CI** (a cada push e PR): verifica sha256 das ferramentas, `wally install`, formatação (`stylua --check`), lint (`selene`) e os dois builds do Rojo.
- **Não executado no CI:** os testes TestEZ e a checagem de tipos `--!strict` com `luau-analyze` (ver `problemas-e-aprendizados.md`).
- **Comandos de teste no Studio:** `rojo serve test.project.json`, depois conectar pelo plugin do Rojo.
- **Código de teste fora do jogo final:** `tests/` e o TestEZ só entram no `test.project.json`. O build de produção foi verificado e não os contém.

## 12. Segurança — checklist
- [ ] Nenhum saldo ou item é alterado a partir de dados do cliente sem validação. *(base: NetService. Economia virá na Fase 2)*
- [ ] Todos os remotes passam por validação de tipo e faixa. *(mecanismo implementado; testes no Studio pendentes; nenhum remote de gameplay ainda)*
- [ ] Rate limit em todos os remotes. *(mecanismo implementado; validação no Studio pendente)*
- [ ] Dados de versão incompatível não são alterados. *(implementado; testes de lógica escritos, ainda não executados no Studio)*
- [x] Nenhuma chave, token ou segredo no código ou na documentação. *(verificado na revisão do ProfileStore e nos arquivos criados)*
- [ ] Logs de transações de economia para auditoria. *(Fase 2)*
- [ ] Alcance e cooldown em coleta. *(Fase 2)*

## 13. Pendências técnicas
1. Validar o bootstrap, o carregamento de perfil, a expulsão e o encerramento de sessão no Studio com dois clientes.
2. Confirmar o uso de `os.clock()` para o rate limit com a versão atual do Roblox (ou trocar por `time()` se houver diferença).
3. Habilitar a checagem `--!strict` no CI com `luau-analyze` e as definições de tipo do Roblox, após aprovação (ver P-006). Os módulos de lógica pura já passam.
