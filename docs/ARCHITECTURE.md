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
- **Servidor** (`src/server/init.server.luau`): ordem `NetService` → `DataService` → `IslandService` → `BuildService` → `ProductionService` → `MarketService` → `ExpansionService` → `ObjectiveService`. Novos serviços entram aqui, e não em outros scripts.
- **Cliente** (`src/client/init.client.luau`): inicia `InputModeController`.

## 4. Serviços do servidor
### 4.1 DataService (base da Fase 1)
Única camada que conversa com o ProfileStore. Outros serviços usam:

| Função | Uso |
|---|---|
| `DataService.GetData(player)` | Cópia profunda somente leitura dos dados, ou `nil` se não carregados ou inativos. Alterar a cópia não altera os dados salvos |
| `DataService.Mutate(player, fn)` | Única forma de alterar dados. A função recebe uma cópia; o resultado só substitui os dados se ela terminar sem erro. Retorna `false` se o perfil não estiver ativo ou se a função falhar (os dados ficam como estavam) |
| `DataService.IsLoaded(player)` | Verifica se o perfil está carregado |
| `DataService.OnLoaded(fn)` | Callback quando o perfil de um jogador é carregado |
| `DataService.Read(player)` | Leitura **sem cópia**, para caminhos frequentes (relógio de produção, objetivos, publicação de estado). Devolve a tabela congelada (D-046): não altere nem guarde a referência. O leitor roda em corrotina e é encerrado com erro se esperar (D-039) |
| `DataService.OnChanged(fn)` | Avisa mudanças de perfil, no máximo uma vez por quadro por jogador (D-039) |

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
- **Perfil congelado (D-046):** os dados guardados são congelados (`DeepCopy.Freeze`) após cada carga e cada `Mutate`. Alterar a tabela congelada gera erro.
- **Perfil temporário de teste (D-040, D-046):** no Studio, com o atributo `FreshProfile = true` no `Workspace` (definido em modo Edit, sem salvar o lugar), o `DataService` usa `ProfileStore.Mock`. Fica só na memória e não lê nem grava DataStore. Serve para testar jogador novo sem tocar em perfis reais. A decisão está em `Logic/ProfileSource.UseMock(isStudio, atributo)`: só no Studio e só com o atributo exatamente `true`. Fora do Studio, o atributo é ignorado com aviso.

### 4.2 NetService (base da Fase 1)
Ponto único de entrada de RemoteEvents. Cada remote passa, nesta ordem, por:
1. **Rate limit** por jogador e por remote (balde de fichas, `RateLimiter`).
2. **Validação** dos argumentos (`Validate` e validadores específicos do remote).
3. **Handler** do sistema, que só roda se as duas etapas anteriores passarem.

Os remotes ficam em `ReplicatedStorage/Remotes`, criados pelo servidor.
Remotes de saída (servidor → cliente) são criados por `NetService.CreateOutgoing` (D-025).

### 4.2b IslandService (Fase 2, primeiro ciclo jogável)
- Cria 8 ilhas (`Workspace/Islands`, limite em `Config/Gameplay`). Cada ilha tem 4 árvores com `ProximityPrompt`.
- Ao entrar, o jogador recebe a primeira ilha livre (`Logic/IslandAllocator`); ao sair, a ilha é liberada e as árvores reiniciadas. Sem ilha livre, o jogador é desconectado com aviso.
- Coleta (`CollectResource`, via `NetService`): o servidor valida o ID, o dono da ilha, o cooldown e o alcance (`Logic/Collect`), depois soma o saldo com `DataService.Mutate` (`Logic/ResourceLedger`).
- O servidor envia `ResourcesChanged` (saldo) e `ResourceCollected(nodeId, amount, resourceId, cooldown)` (confirmação para o efeito visual). `RequestResources` pede o saldo inicial.
- Cliente: `Resources/ResourceController` mostra o saldo, o popup de coleta e envia apenas o pedido.

### 4.2c BuildService (Fase 2, construção)
- Cada ilha tem 8 pontos fixos (`Gameplay.Build.Sites`, B1–B8; B5–B8 em D-032) com marcador e `ProximityPrompt`. O modelo da ilha guarda o atributo `OwnerUserId` (público), e o cliente só abre a construção na ilha do próprio jogador.
- Pedido `BuildStructure(ponto, estrutura)`: o cliente não informa ilha, preço nem posição. O servidor usa a ilha do jogador, o alcance e o catálogo de `Config/Gameplay`.
- Regras puras em `Logic/Build.Apply`: ilha → ponto → estrutura → alcance → ocupação → saldo. Ocupação e desconto acontecem na mesma `DataService.Mutate`, então compras simultâneas no mesmo ponto não são cobradas duas vezes.
- Persistência: `Buildings` no perfil (`ponto local → estrutura`), schema 3 com migração em `Logic/PlayerMigrations`. Ao carregar, `Build.Restore` descarta valores desconhecidos e recria as estruturas sem duplicar. Ao sair, as estruturas visuais da ilha são removidas.
- Resultado (`BuildResult`) é enviado ao jogador que pediu, com o motivo. Após compra aceita, o saldo é reenviado (`IslandService.SendSnapshot`).
- Cliente: `Build/BuildController` mostra o painel (custo, madeira, confirmação e resultado). Efeito visual de construção em `UI/Popup`.

### 4.2d Mundo, arte e apresentação (vertical slice visual, D-027)
- **Tudo gerado por código e versionado pelo Rojo**; nada depende de salvar o lugar.
- `Server/World/Environment`: iluminação e pós-processamento, oceano em Terrain, relevo de cada ilha (praia, grama com borda irregular, colina, clareira de areia e caminho), `WaitForGround` e `GroundY`. Esconde `Baseplate` e `SpawnLocation` sem apagá-los (D-030).
- `Server/World/IslandDecor`: pedras, arbustos, flores, caminho, placa (âncora do nome do dono) e píer.
- `Shared/Art/Palette` (cores do mundo e da interface) e `Shared/Art/Models` (palmeira, cerca, cabana, marcador e decoração). Usados pelo servidor no mundo e pelo cliente nas prévias do painel.
- **Ordem no `IslandService.Init`:** ambiente → relevo de todas as ilhas → espera o terreno responder → mede o chão da clareira (origem da ilha) → objetos. Ver P-014.
- **Layout da ilha (frente = +Z):** chegada e píer na frente, clareira de construção no centro (B1–B8), palmeiras no fundo e nas laterais.
- **Cliente:** `UI/Theme` (fontes, cantos, botões animados, ícone de madeira desenhado), `UI/Effects` (partículas, sons, animação de construção), `UI/Popup`, `Onboarding/OnboardingController` (objetivo + feixe guia, etapa de `Logic/Onboarding`, D-029).
- **Feedback só no cliente e só visual:** popups, partículas, sons e a animação de construção não alteram o estado; o servidor continua dono do resultado.

### 4.2e ProductionService (Serraria, primeira automação, D-031)
- **Lógica pura** em `Shared/Logic/Production` (`Step`, `Stored`, `Sanitize`, `Harvest`). Regras por estrutura em `Config/Gameplay.Production.Producers` (quantidade por ciclo e intervalo em segundos).
- **Relógio único** de 1 s no servidor. Só produz para o dono conectado. O progresso fica só em memória: é zerado a cada sessão e não há produção offline.
- **Estoque** por ponto em `Storage` (ponto local → quantidade), persistido no perfil. Alterado somente por `DataService.Mutate`.
- **Coleta** (`HarvestProduction`, via `NetService`): move todo o estoque do ponto numa única mutação, sem duplicação. Resultado (`HarvestResult`) com motivo: `Ok`, `Empty`, `OutOfReach`, `NotProducer` etc. Rate limit de 4 pedidos por 2 s.
- **Estoque cheio:** a produção pausa e zera o progresso.
- **Reuso:** a Serraria é uma estrutura do `BuildService`. `ProductionService` usa `OnPlaced` e `GetStructure`. Compra no ponto zera o estoque daquele ponto.
- Cliente: `Client/Production/ProductionController` mostra o indicador, animações e efeitos. Só envia o pedido de coleta.

### 4.2f Economia, melhorias, expansão e objetivos (2026-11-27, D-034 a D-038)
- **Fonte única de valores:** `Config/Economy` tem recursos (Madeira, Pedra, Moedas), preços de venda, custos de estruturas, níveis de melhoria da Serraria, expansões e recompensas de objetivos. Todos os valores são **provisórios** e devem ser ajustados após teste com jogadores (D-034).
- **Lógica pura:** `Logic/Cost` (custo com vários recursos, tudo ou nada), `Logic/Market`, `Logic/Upgrade`, `Logic/Expansion`, `Logic/Objectives`, `Logic/Stats`. Cada compra, venda ou melhoria roda numa única `DataService.Mutate`, então nada é cobrado nem creditado duas vezes (D-035).
- **`MarketService`:** venda por `SellResource(recurso, quantidade)`; resposta em `SellResult`. Lote máximo de 300. Só vende a partir do píer (alcance validado no servidor).
- **Melhoria da Serraria:** `UpgradeProducer(ponto)` com resposta em `UpgradeResult(ponto, resultado, nível)`. Níveis 1 a 5 mudam velocidade, capacidade e custo. Até 2 Serrarias por ilha.
- **`ExpansionService`:** `ExpandIsland(área)` com resposta em `ExpandResult(área, resultado)`. Na compra, o terreno da área sobe do mar em etapas. Ao sair do dono, a área volta ao mar, porque a ilha pode ir para outro jogador. Pontos de expansão ficam ocultos e recusados (`Locked`, em `BuildService` e `Logic/Build`) até a liberação. Expansão atual: Enseada Leste (E1), com pontos X1–X3.
- **`ObjectiveService`:** progresso calculado do estado do perfil. `RequestObjective()` pede o estado; `ObjectiveChanged(estado, concluídos)` é enviado só quando muda. Ao carregar, objetivos já cumpridos são marcados sem recompensa. A recompensa entra na mesma mutação que conclui o objetivo. Substitui a orientação derivada no cliente (D-029).
- **Cliente:** `Client/Market`, `Client/Upgrade`, `Client/Expansion` e `Client/Onboarding` (cartão de objetivos e feixe-guia) só abrem painéis e enviam pedidos. A interface de apoio fica em `Client/UI` (`Panel`, `Toast`, `Format`, `World`).

### 4.2g Cadeias produtivas, pedidos e estágios (2026-11-27, D-041 a D-046)
- **Cadeias no mesmo `ProductionService`:** a regra de produção ganhou entrada opcional (`InputId`, `InputAmount`, `InputCapacity`). `Production.StepConverter` consome e produz no mesmo passo, e para sem matéria-prima ou sem espaço. `Production.Supply` abastece a entrada a partir do saldo, numa só mutação (`SupplyProducer` → `SupplyResult`). Entrada salva por ponto em `Inputs`.
- **Pedidos (`Logic/Orders`):** 3 vagas em sequência fixa e cíclica. `DeliverOrder(vaga, número do pedido)` responde com `OrderResult`; repetição de pedido antigo responde `Stale`. A entrega consome os recursos e troca o pedido na mesma mutação. `RequestOrders` pede o estado, enviado em `OrdersChanged`.
- **Estágios (`Logic/Stages`, `Stage` no perfil):** `AdvanceStage` responde com `StageResult`. Requisitos e recompensa são verificados e aplicados na mesma mutação, então o estágio não pode ser pago duas vezes.
- **Perfil congelado (D-046):** `DataService` congela os dados (`DeepCopy.Freeze`) após cada carga e cada `Mutate`. `Read` entrega a tabela congelada e roda o leitor numa corrotina, que é encerrada com erro se esperar.
- **Perfil temporário:** a decisão fica em `Logic/ProfileSource.UseMock` (D-046).
- **Schema 6:** `Inputs`, `Orders` e `Stage`, com migração v5 → v6 em `Logic/PlayerMigrations`.
- **Cliente:** `Client/Supply` (painel de abastecimento), `Client/Stage` (painel de estágio), `Client/State/ClientState` (estado recebido do servidor), `Client/WorldGui` (placa da ilha e indicadores) e `Client/UI/Components` (componentes reutilizáveis). O mercado tem abas Vender e Pedidos em `Client/Market`. O cliente só envia intenções.
- **Expansão:** ao liberar a ilha, a expansão é apagada por inteiro, com área e faixa de areia (D-047).

### 4.3 Serviços previstos (fases seguintes, sem implementação ainda)
| Serviço | Fase | Responsabilidade |
|---|---|---|
| ~~`EconomyService`~~ | 2 | Não será criado: moedas ficam em `Resources` (D-035); venda no `MarketService`, custos em `Logic/Cost` |
| `InventoryService` | 2 | Itens do jogador. Limite de slots |
| `ResourceService` | 2 | Nós de coleta: cooldown, respawn, alcance |
| `IslandService` | 3 | Atribui um lote de ilha a cada jogador |
| `BuildService` | 2 | Implementado (ver 4.2c): pontos fixos, custo, propriedade e alcance. Área livre e colisão ficam para a fase de ilhas |
| `ProductionService` | 2 | Implementado (ver 4.2e): primeira máquina, a Serraria (D-031) |
| `AutomationService` | 4 | Produção das máquinas em geral (ver seção 7). Pode reaproveitar `ProductionService` |
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
- Versão do schema em `PlayerData.SchemaVersion` (atual: 6; v2 adicionou `Resources`, ver D-024; v3 adicionou `Buildings`, ver D-026; v4 adicionou `Storage` (ponto → quantidade), ver D-031; v5 adicionou `Levels` (nível por ponto), `Expansions`, `Stats` (estatísticas para objetivos) e `Objective` (objetivos concluídos), ver D-036; v6 adicionou `Inputs`, `Orders` e `Stage`, ver D-041 a D-045; migrações em `Logic/PlayerMigrations`). Mudar o schema exige: incrementar `Persistence.SchemaVersion`, registrar a migração em `DataService` (`MIGRATIONS`) e adicionar teste em `tests/Logic`.

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
