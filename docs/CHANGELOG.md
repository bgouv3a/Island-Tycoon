# Changelog — Island Rebuild

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

## [Não lançado]

### 2026-11-27 — Cadeias produtivas, pedidos e Ilha produtiva
#### Adicionado
- **Pedreira e Carpintaria:** a Pedreira produz pedra. A Carpintaria transforma 2 madeira em 1 tábua, com entrada e saída. Ambas param sem madeira ou com a saída cheia. Ficam no `ProductionService` generalizado (`Production.StepConverter` e `Production.Supply`, D-041). Valores em D-042.
- **Tábuas (`Planks`):** venda de 5 moedas, lote máximo de 200.
- **Pedidos comerciais no píer:** 3 vagas, sequência fixa de 8 modelos, pagam cerca de 1,4 a 1,6 vez a venda direta (D-043).
- **Estágios da ilha:** Ilha inicial → Ilha produtiva (D-044). Requisitos: Enseada Leste, 20 tábuas produzidas e 2 pedidos entregues. Benefícios: +1 máquina de cada tipo, pedidos +25% e 100 moedas.
- **Objetivos 9 a 13** (D-045).
- **Schema 6:** `Inputs`, `Orders` e `Stage` (D-045). Migração v5 → v6 em `Logic/PlayerMigrations`.
- **Preço com vários recursos** e **limite por estágio** (D-042).
- **Remotes novos:** `SupplyProducer`/`SupplyResult`, `DeliverOrder`/`OrderResult`, `RequestOrders`/`OrdersChanged`, `AdvanceStage`/`StageResult`.
- **Modelos novos:** Pedreira com paredão em degraus, guindaste e britadeira; Carpintaria com telhado de palha, serra e funil; passadiço na faixa da Enseada.
- **Cliente:**
  - painel de abastecimento (`Client/Supply`);
  - mercado com abas Vender e Pedidos;
  - painel de estágio (`Client/Stage`);
  - componentes reutilizáveis (`UI/Components`);
  - `ClientState`, com o estado recebido do servidor;
  - HUD abaixo do chat;
  - placa do nome da ilha limitada em pixels e oculta de perto;
  - indicadores que somem quando um prompt da máquina aparece;
  - animação genérica Spin/Bob.
- Arquivos novos: `src/shared/Logic/{Orders,Stages,ProfileSource}.luau`, `src/client/{Stage,State,Supply,WorldGui}/`, `src/client/UI/Components.luau`, `tests/Logic/Chains.spec.luau`.

#### Segurança
- **Perfil congelado** no `DataService` após cada carga e cada `Mutate` (D-046). `Read` e `Mutate` não podem esperar (yield).
- **`FreshProfile` só no Studio**, decidido por `Logic/ProfileSource` (D-046). Fora do Studio o atributo é ignorado.

#### Corrigido
- **Resto de areia ao liberar a expansão:** a expansão é apagada por inteiro, com área e faixa de areia, e a ilha principal é moldada de novo com a mesma semente (D-047, P-022).

#### Verificado
- TestEZ: **152 aprovados, 0 falhas** (129 anteriores + 23 novos em `Chains.spec` e `PlayerMigrations.spec`).
- No Studio (Rojo conectado), pelos remotes reais:
  - Migração v5 → v6 com objetivos retomados no 9.
  - Entrega de pedido `Ok` e repetição `Stale`; vaga inválida recusada.
  - Pedreira comprada; segunda compra barrada (`Limit`).
  - Carpintaria comprada e abastecida (30); segundo abastecimento `InputFull`.
  - Consumo exato de 2 madeira por tábua (entrada + 2 × saída constante).
  - Parada sem madeira (`Starved`).
  - Recolher tábuas e pedra; venda de tábuas.
  - Melhoria da Pedreira para o nível 2.
  - Estágio 2 liberado uma vez (+100 moedas); repetição `MaxStage`.
  - Bônus de +25% nos pedidos.
  - Persistência após reiniciar.
  - Limpeza do terreno ao liberar a ilha: área e faixa voltam ao mar.
  - Painel de estágio com requisitos no `FreshProfile`.
- Builds do Rojo (produção e teste) OK.

#### Não verificado
- **Aparência 3D** dos modelos novos: aguardando capturas do dono (P-016).
- **Resoluções 1366×768, 1920×1080 e celular:** só a lógica de escala foi verificada.
- **Dois jogadores ao mesmo tempo.**
- **Lint e tipos:** StyLua, Selene e luau-analyze não instalados.
- **Balanceamento com jogadores:** os valores de D-042 são provisórios.

### 2026-11-27 — Economia, melhorias, expansão e objetivos
#### Adicionado
- **Pedra (`Stone`):** 3 rochas coletáveis na ilha e 2 na expansão. Cada coleta rende 2 pedras; recuperação de 12 s (D-034, provisório).
- **Moedas e mercado no píer:** `MarketService` vende Madeira (1 moeda) e Pedra (3 moedas), com lote máximo de 300. Moedas (`Coins`) ficam no mesmo `Resources` (D-035).
- **Melhorias da Serraria, níveis 1 a 5:** cada nível muda velocidade, capacidade e custo (D-034). O modelo muda visualmente por nível.
- **Limite de 2 Serrarias por ilha.**
- **Expansão Enseada Leste (E1):** custo de 120 moedas, 40 madeiras e 20 pedras. Pontos X1–X3, 2 palmeiras e 2 rochas. O terreno sobe do mar na compra e volta ao mar quando o dono sai (D-038).
- **Objetivos:** 8 objetivos iniciais com recompensas concedidas pelo servidor (`ObjectiveService`, D-037).
- **Schema 5:** `Levels`, `Expansions`, `Stats` e `Objective` (D-036). Migração v4 → v5 em `Logic/PlayerMigrations`; quem já construiu recebe `Stats.WoodCollected = 6`.
- `Config/Economy`: fonte única de preços, custos, níveis, expansões e recompensas (D-034).
- `DataService.Read` (leitura sem cópia) e `DataService.OnChanged` (aviso de mudança uma vez por quadro), D-039.
- **Perfil temporário no Studio:** atributo `FreshProfile = true` no Workspace faz o `DataService` usar `ProfileStore.Mock`, sem ler nem gravar DataStore (D-040).
- **Interface:** HUD com vários recursos; painéis de venda e de melhoria; rótulo de expansão; cartão de objetivos (`UI/Panel`, `UI/Toast`, `UI/Format`, `UI/World`).
- **Passe de arte:** rocha com minério, barraca do mercado, placa de expansão, boias, pátio de trabalho nas estruturas produtivas e jardineiras na cabana.
- Arquivos novos:
  - `src/shared/Config/Economy.luau`
  - `src/shared/Logic/{Cost,Market,Stats,Upgrade,Objectives,Expansion}.luau`
  - `src/server/Services/{MarketService,ExpansionService,ObjectiveService}.luau`
  - `src/client/Market/MarketController.luau`, `src/client/Upgrade/UpgradeController.luau`, `src/client/Expansion/ExpansionController.luau`
  - `src/client/UI/{Panel,Toast,Format,World}.luau`
  - `tests/Logic/{Economy,Progression}.spec.luau`
- **Remotes novos:** `SellResource`/`SellResult`, `UpgradeProducer`/`UpgradeResult`, `ExpandIsland`/`ExpandResult`, `RequestObjective`/`ObjectiveChanged`.

#### Alterado
- `ResourceCollected` agora envia `(nodeId, amount, resourceId, cooldown)`.
- **Objetivos:** a orientação derivada no cliente foi substituída pelo estado do servidor (D-037).
- Bootstrap do servidor: Net, Data, Island, Build, Production, Market, Expansion, Objective.

#### Corrigido
- **Condição de corrida da orientação:** o tempo de espera de 2,5 s foi removido. O estado vem do servidor, e a recompensa não sai duas vezes (D-037).
- **Revisão:** o relógio de produção passou a ser protegido por `pcall`.
- **Revisão:** as estruturas da expansão só aparecem depois que o terreno está pronto.

#### Verificado
- TestEZ: **129 aprovados, 0 falhas** (100 anteriores + 29 novos em `Economy`, `Progression` e `PlayerMigrations`).
- No Studio (Rojo conectado), pelos remotes reais, com o perfil de teste:
  - Migração v4→v5 sem perda (6 construções, estoque); objetivos retomados no 4/8, sem recompensas em cascata.
  - Recolher: Ok(30), repetição imediata Empty.
  - Pedra: 2 por coleta; segunda coleta no mesmo instante recusada.
  - Venda: Ok(50 madeira → 50 moedas); 100000, 1,5 e 999 recusados (InvalidAmount); moedas recusadas (NotSellable).
  - Melhoria: fora do alcance recusada; Ok para o nível 2 (cobrou 25 moedas + 4 pedra uma vez); repetição Insufficient; Cerca NotUpgradable; peças de nível visíveis.
  - Expansão: longe OutOfReach; área inválida UnknownArea; Ok, repetição AlreadyOwned, Ready em ~1,8 s; X1–X3 abertos.
  - Limite de 2 Serrarias por ilha (Limit).
  - Persistência após reiniciar: área, nível 2, objetivos e saldo; cerca em X2 restaurada sobre o terreno da expansão.
  - Perfil temporário (FreshProfile): começa do zero no objetivo 1/8 e recebe a recompensa; o perfil real não foi alterado.
- Builds de produção e teste do Rojo OK; todos os arquivos com `--!strict`.

#### Não verificado
- **Imagem 3D** dos modelos novos (P-016): aguardando capturas do dono.
- **Dois jogadores ao mesmo tempo**, aparência no celular e lint/tipos (StyLua, Selene e luau-analyze não instalados).
- **Balanceamento com jogadores:** os valores são provisórios (D-034).

### 2026-11-26 — Serraria: primeira produção automática
#### Adicionado
- **Serraria (Sawmill):** custo de 15 madeiras, produz 1 madeira a cada 5 s, capacidade 30. Produz só com o dono conectado. A coleta é manual (D-031).
- `Logic/Production` (lógica pura: `Step`, `Stored`, `Sanitize`, `Harvest`) e `Services/ProductionService` (servidor): relógio único de 1 s, progresso só em memória, estoque salvo em `Storage` por `DataService.Mutate`.
- Remotes `HarvestProduction` (pedido, com rate limit: até 4 pedidos seguidos, recarga de 2 por segundo) e `HarvestResult` (resultado com motivo).
- `BuildService`: ganhou `OnPlaced` e `GetStructure`. Ao comprar no ponto, zera o estoque daquele ponto.
- Pontos de construção **B5 (-13, 12)**, **B6 (13, 12)**, **B7 (-23, -3)** e **B8 (23, -3)**, com clareiras de areia (D-032).
- Cliente `Client/Production/ProductionController`: indicador "N/30" com barra; "Cheio!" pulsando; lâmina, roda e tora animadas e serragem só perto da câmera; popup, partículas e som na coleta; aviso "Serraria cheia!".
- Orientação: Coletar → Construir → Juntar 15 → Construir Serraria → Aguardar → Recolher → concluído. Quem começa a sessão já com a Serraria não vê a orientação.
- Painel de construção com 3 cartões, prévia enquadrada pela bounding box e linha "Produz N madeira a cada T s".
- **Visual:** modelo low-poly da Serraria (37 peças); pedras facetadas (4 peças, 3 tons).
- Testes TestEZ: `Production` (+15 casos), `Onboarding` reescrito (9), migração v4 (+3).

#### Alterado
- **Schema 3 → 4:** `Storage` (ponto → quantidade) no perfil. Migração v4 em `Logic/PlayerMigrations`. Template do `DataService` atualizado.
- Palmeiras reposicionadas e mais esguias, com folhas em arco e tons naturais. Duas palmeiras foram movidas para abrir espaço para os novos pontos.
- Decoração reposicionada para os novos pontos. Pontos B1–B4 e construções existentes preservados.
- **Iluminação:** sol mais baixo (`ClockTime` 15.3), sombras mais definidas e névoa leve.
- **Gramado:** trocado de `Grass` para `LeafyGrass`, sem grama decorativa alta, com cor menos saturada (D-033).
- Clareiras e caminho em areia.

#### Corrigido durante a revisão
- Revisão (quality-reviewer): o feixe da orientação falhava após o respawn (attachment destruído). Corrigido.
- Revisão: estado órfão se o jogador saía durante o carregamento. Corrigido.

#### Verificado
- TestEZ: **100 aprovados, 0 falhas**.
- Builds do Rojo de produção e de teste gerados.
- **Studio (`Island Tycoon - testes`):**
  - Compra da Serraria: cobrança única (40 → 25). Recusas `OutOfReach`, `Occupied` e compra duplicada.
  - Produção: 1 madeira a cada 5 s. Na capacidade 30, a produção pausa e a animação para.
  - Coleta: `Ok`; segunda coleta `Empty`; `OutOfReach`; `NotProducer`; argumento inválido recusado.
  - Persistência após reinício: estoque mantido, saldo 61 e 5 construções sem duplicar. Sem produção offline.
  - Respawn sem erro no console.
- Agentes usados: Opus (arquitetura, economia, servidor, integração e testes no Studio); game-developer/Sonnet (cliente); world-builder/Sonnet (modelo e ajustes visuais); quality-reviewer/Sonnet (revisão); fast-assistant/Haiku (documentação).

#### Não verificado
- **Imagem 3D da cena:** não capturada (P-016 continua).
- **Experiência de jogador novo com perfil isolado:** o Studio usa o UserId real. Testada pela lógica pura (P-018).
- **Dois clientes ao mesmo tempo.**
- **Lint e tipos:** StyLua, Selene e luau-analyze não executados (ferramentas ausentes neste ambiente).

### 2026-11-26 — Vertical slice visual e jogável da ilha inicial
#### Adicionado
- **Cenário gerado por código:** oceano em Terrain, ilha com contorno irregular, praia, colina, clareira de construção em areia, caminho de pedras, flores, arbustos, pedras, placa com o nome do dono e píer (`Server/World/Environment`, `Server/World/IslandDecor`).
- **Iluminação:** tarde tropical, atmosfera, bloom leve, correção de cor; desfoque de profundidade desligado (leitura e celular).
- **Modelos low-poly** (`Shared/Art/Models`, `Shared/Art/Palette`): palmeira (tronco curvo, folhas caídas, cocos), cerca, cabana (telhado de duas águas, porta, janelas, chaminé), marcador de construção (placa, anel, estacas) e decoração.
- **Interface nova** (`Client/UI/Theme`): contador de madeira com ícone desenhado; painel de construção com prévia 3D, custo, estado (pode pagar, faltam N, confirmar) e confirmação no segundo toque; botões com animação; painel abre com animação e fecha ao se afastar.
- **Feedback** (`Client/UI/Effects`, `Client/UI/Popup`): popup "+2 Madeira", lascas e folhas, contagem "Cresce em Ns" sobre a palmeira, pulso no contador; na construção, as peças descem com quique, poeira, brilho e som; tremida em recusas.
- **Sons** (`Config/Audio`): corte de madeira e martelo de madeira, ambos da ProSoundEffects (gratuitos, parceira oficial).
- **Orientação inicial** (`Client/Onboarding`, `Logic/Onboarding`): objetivo com progresso ("Colete madeira 1/2", "Vá até um ponto amarelo") e feixe de luz até a próxima palmeira pronta ou ponto livre. Some após a primeira construção.
- Testes TestEZ: `Onboarding` (+5).

#### Alterado
- Palmeiras substituem as árvores de bloco e bola: 6 por ilha, no fundo e nas laterais. A copa some enquanto a palmeira se recupera.
- Pontos de construção reposicionados numa clareira (B1–B4 mantêm os nomes salvos nos perfis). Estruturas olham para a chegada.
- Chegada do jogador na frente da ilha, olhando para a clareira.
- **Ritmo:** 2 de madeira por coleta (era 1) e recuperação de 6 s (era 8) (D-028).
- Atributos públicos para o cliente guiar o jogador: `Ready` (palmeira) e `Open` (ponto).
- Mensagens e ícones sem emoji (não renderizaram no Studio).

#### Corrigido durante a entrega
- Sintaxe ambígua em `IslandService` (linha iniciada por parênteses).
- Objetos enterrados por arredondamento do Terrain e raycast imediato após o preenchimento (P-014).
- Contador de madeira sobreposto ao chat; objetivo movido para a lateral direita.

#### Verificado
- TestEZ no Studio: **78 aprovados, 0 falhas**. Sem erros nem avisos no console.
- Builds do Rojo (produção e teste) gerados; produção sem testes nem TestEZ.
- **Studio (perfil de teste, `_Studio`):** coleta +2 com copa escondida, contagem e retorno após 6 s; HUD atualizado; recusa por ponto ocupado sem cobrança; 4 construções restauradas com os modelos novos; saldo persistido entre sessões (12).
- **Medições:** chão em 2,0 em todos os pontos; estruturas, marcadores e decoração assentados; água em −2.
- Sons carregam (`ContentProvider`: Success).
- Studio igual ao repositório: checksum de cada script conferido (P-015).
- Interface do painel, contador e objetivo inspecionados por captura.

#### Não verificado
- **Imagem "depois" da cena 3D:** o viewport do Studio parou de renderizar durante a sessão (P-016). A imagem "antes" existe.
- **Prévias 3D do painel:** os modelos estão nos `ViewportFrame`, mas a imagem depende da mesma renderização.
- **Construção bem-sucedida com o visual novo:** o perfil de teste tem os 4 pontos ocupados. Não apaguei dados para liberar um ponto. O caminho do servidor (`Models.Structure`) foi exercitado pela restauração; a animação de construção no cliente não foi vista.
- **Orientação para jogador novo:** o perfil de teste já construiu, então ela fica oculta (correto). As etapas estão cobertas pelos testes de `Onboarding`.
- Layout em celular e em telas pequenas; dois jogadores; lint e tipos (ferramentas ausentes).

### 2026-11-26 — Subagentes do Claude Code
#### Adicionado
- `.claude/agents/`: `fast-assistant` (haiku), `game-developer` (sonnet), `world-builder` (sonnet), `quality-reviewer` (sonnet).
- `CLAUDE.md`: seção "Modelos e subagentes" com as regras de delegação.
- `docs/skills-e-ferramentas.md`: registro dos subagentes.

#### Não alterado
- Código do jogo, dados, assets, permissões e configurações globais. Nenhuma operação Git.

### 2026-11-26 — Fase 2: sistema de construção
#### Adicionado
- Construção em pontos fixos da ilha (B1–B4), com marcador visível e `ProximityPrompt`.
- Estruturas: **Cerca** (2 madeira) e **Cabana** (5 madeira), com custo mostrado na interface.
- `Logic/Build.luau` (regras puras: `Apply`, `Restore`), `Logic/ResourceLedger.Spend` (débito atômico).
- `Server/Services/BuildService.luau`: valida o pedido, desconta a madeira pelo `DataService.Mutate`, cria e restaura as estruturas.
- `Client/Build/BuildController.luau`: painel com lista, custo, madeira disponível, confirmação e motivo da recusa.
- `Client/UI/Popup.luau`: popup de feedback, agora compartilhado por coleta e construção.
- `Config/Gameplay.luau`: seção `Build` (alcance, pontos, estruturas) e limites do remote `BuildStructure`.
- Testes TestEZ: `Build` (11 casos de compra e 4 de restauração), `Spend` (+4), migração v2 → v3 (+4).

#### Alterado
- Schema **2 → 3**: `Buildings` no perfil, com migração em `Logic/PlayerMigrations`. Perfis antigos recebem nenhuma construção.
- `IslandService`: guarda o modelo da ilha, cria a pasta `Builds`, marca o dono (`OwnerUserId`) e expõe `GetSlot`, `GetOrigin`, `GetIsland`, `SendSnapshot`.
- `init.server` inicia `BuildService` depois do `IslandService`. `init.client` inicia `BuildController`.
- `ResourceController` usa o `Popup` compartilhado (mesmo visual).

#### Verificado
- TestEZ no Studio: **73 aprovados, 0 falhas** (50 anteriores + 23 novos).
- Builds do Rojo: `default.project.json` e `test.project.json` gerados. Produção sem TestEZ.
- Studio (uma pessoa, `_Studio`):
  - Compra válida: Cerca em B1 → `Ok`, madeira 14 → 12 (após correção P-013).
  - Ponto ocupado: repetir B1 → `Occupied`, sem cobrança.
  - Alcance: pedido com personagem longe → `OutOfReach`, sem cobrança.
  - Compras simultâneas no mesmo ponto (B4, Cabana): uma `Ok`, uma `Occupied`, cobrança única (12 → 7).
  - Persistência: após sair e entrar, as 4 estruturas voltaram (Cerca B1/B3, Cabana B2/B4), sem duplicar, e o saldo 7 foi mantido.
  - Marcadores de pontos ocupados ficam fechados; livres continuam abertos.

#### Não verificado
- **Recusa por madeira insuficiente no Studio:** coberta nos testes de lógica (saldo 1, custo 5). No teste de jogo não foi reproduzida, porque o saldo ficou acima do custo dos pontos livres.
- **Dois jogadores ao mesmo tempo** (ilhas diferentes, liberação ao sair). Exige dois clientes.
- **Layout do painel** em telas diferentes (PC, mobile, tela pequena): não medido no Studio.
- **Lint e tipos** (StyLua, Selene, luau-analyze): as ferramentas continuam ausentes do ambiente. Não executados.
- **Dados de teste:** o perfil de teste em `IslandRebuild_PlayerData_Studio` ficou com Cerca, Cabana e saldo 7. Limpeza só com autorização.

### 2026-11-26 — Documentação: decisão D-026 e problema P-013
- Decisões D-026 e problema P-013 registrados em `decisoes.md` e `problemas-e-aprendizados.md`.
- `ARCHITECTURE.md` seção 8: versão atual do schema corrigida de 2 para 3 (faltou na entrega da construção).

### 2026-11-25 — Fase 2 (início): ilhas individuais e coleta de madeira
#### Adicionado
- `Config/Gameplay.luau`: limites de ilhas, recurso Madeira, cooldown, alcance e limites de remotes.
- `Logic/IslandAllocator.luau`, `Logic/ResourceLedger.luau`, `Logic/Collect.luau`, `Logic/PlayerMigrations.luau` (lógica pura).
- `Server/Services/IslandService.luau`: ilhas, atribuição, coleta validada no servidor.
- `Client/Resources/ResourceController.luau`: saldo na tela, popup de coleta, pedido de coleta.
- `NetService.CreateOutgoing` (D-025) e as decisões D-024 e D-025.
- Testes TestEZ: `IslandAllocator`, `ResourceLedger`, `Collect`, `PlayerMigrations` (+20 casos).

#### Alterado
- `PlayerData` ganha `Resources`. Schema **1 → 2** com migração em `Logic/PlayerMigrations` (perfis novos já nascem com `Resources`).
- `init.server` inicia `IslandService` depois do `DataService`. `init.client` inicia `ResourceController`.

#### Verificado
- Testes TestEZ no Studio: **50 aprovados, 0 falhas** (30 anteriores + 20 novos).
- Studio (uma pessoa, ambiente `_Studio`): ao entrar, o jogador foi colocado na Ilha 1 com o nome na plataforma. Migração v1→v2 aplicada ao perfil de teste existente.
- Coleta (cliente pedindo, servidor decidindo): coleta válida +1; cooldown bloqueou a repetição; árvore fora de alcance, árvore de outra ilha, ID inexistente, tipo inválido e texto longo não alteraram o saldo; spam de 15 chamadas em um cooldown contou só uma vez; após o cooldown, +1.
- Persistência: saldo 3 gravado ao encerrar a rodada 1 e carregado como 3 na rodada 2.
- Script temporário de integração (`IntegracaoIlhas`) criado só no Studio e removido. Nada salvo no lugar.

#### Não verificado
- **Dois jogadores ao mesmo tempo** (ilhas diferentes, liberação de ilha ao sair com outro jogador entrando). Exige dois clientes. A atribuição está coberta pelos testes de `IslandAllocator`.
- Limite de jogadores por servidor e desempenho (Fase 7).
- Verificação de tipos `--!strict` e lint (StyLua, Selene, luau-analyze) dos arquivos novos: as ferramentas não estavam no PATH e não foram executadas nesta etapa.
- Rate limit por tempo real (o efeito foi observado pela cadência de spam, sem medir os limites exatos).

### 2026-11-25 — Validação no Studio do DataService (P1 e P2)
#### Verificado no Studio
- **Experiência de teste** (`Island Tycoon - testes`), DataStore `IslandRebuild_PlayerData_Studio`. Nenhum acesso ao DataStore de produção.
- **Testes TestEZ** (rodados no Studio na inicialização do servidor de teste): 30 aprovados, 0 falhas, 0 ignorados.
- **Rodada 1 (gravação): 10 PASS, 0 FAIL.** Carregamento com sessão, `GetData` (retorna dados, `SchemaVersion == 1`, cópia não altera o estado salvo), `Mutate` com sucesso (alteração visível em `GetData`), `Mutate` com erro (retorna `false` e preserva os dados).
- **Rodada 2 (persistência entre sessões): 9 PASS, 0 FAIL.** O marcador gravado na rodada 1 foi lido após reabrir a sessão, e o erro proposital da rodada 1 não foi salvo.
- **Encerramento entre rodadas:** após cada Stop, `ActiveSession` ficou `nil` (lock liberado) e o `EndSession` gravou o estado.

#### Limpeza (autorizada pelo dono)
- Removido apenas o campo `Data.TesteDataService` do perfil de teste. Comparação completa com o estado esperado: demais dados idênticos. `ActiveSession` não foi tocado.
- Removido o script temporário `TesteDataService` do Studio (não salvo no lugar; nada no repositório).

#### Incidente: lock de sessão preso
- Antes da rodada 1, o perfil de teste tinha um `ActiveSession` sem renovação havia vários minutos. O ProfileStore só o considera morto após 630 s sem atualização (`ASSUME_DEAD`), e a tentativa de iniciar sessão para de repetir após 120 s (`START_SESSION_TIMEOUT`).
- **Decisão:** não remover o lock manualmente nem editar o DataStore para isso. Aguardou-se a expiração natural, após a qual a sessão de teste carregou normalmente.
- Ver P-011.

#### Não verificado
- Expulsão por `TooNew`/`Invalid` e por falha de migração.
- Sessão roubada e saída durante o carregamento (exige dois clientes).
- Falha real do DataStore.
- Separação entre o projeto de produção e o de teste no Studio.

### 2026-11-25 — Correção P1 e P2 da auditoria (DataService)
#### Corrigido
- **P1 — `GetData`:** passa a devolver cópia profunda, e não a tabela viva. Retorna `nil` também para perfis inativos.
- **P2 — `Mutate`:** executa a função sobre uma cópia e só substitui os dados se ela terminar sem erro. Em falha, os dados ficam como estavam e um aviso é registrado.
- Cópia profunda movida de `DataService` para `Logic/DeepCopy.luau` (pura, testável). A migração usa o mesmo módulo.

#### Adicionado
- `src/shared/Logic/DeepCopy.luau` e `src/shared/Logic/Transaction.luau`.
- `tests/Logic/DeepCopy.spec.luau` e `tests/Logic/Transaction.spec.luau`.
- D-023 em `decisoes.md` e P-010 em `problemas-e-aprendizados.md`.

#### Verificado
- `stylua --check src tests`, `selene src tests`: sem erros.
- `rojo build` dos dois projetos: gerados.
- `luau-analyze` 0.748: `DeepCopy` e os módulos já existentes passam. `Transaction` só acusa `script` e `require` do Roblox (erros de ambiente, P-006).
- Specs de lógica (incluindo os existentes): 30 aprovados, 0 falhas, rodados por harness fora do Studio. Com a mutação direta de volta, 4 casos falham.

#### Verificado no Studio (atualizado)
- Comportamento de `GetData` e `Mutate` com um perfil real validado no Studio em 2026-11-25 (rodadas 1 e 2, ver entrada "Validação no Studio do DataService (P1 e P2)" acima).

#### Não verificado
- Nada pendente nesta correção. Os itens ainda não validados (expulsão, sessão roubada, dois clientes) estão na entrada de validação acima.

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
