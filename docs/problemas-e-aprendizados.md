# Problemas e aprendizados — Island Rebuild

Registrar aqui bugs, armadilhas e lições. Para cada item: sintoma, causa, solução e como evitar no futuro.

## Registrados

### P-001 — Nomes de arquivo em maiúsculas e minúsculas colidem no Windows
- **Sintoma:** a regra global pede `roadmap.md` e `changelog.md`, e o projeto pediu `ROADMAP.md` e `CHANGELOG.md`.
- **Causa:** o Windows não diferencia maiúsculas de minúsculas em nomes de arquivo.
- **Solução:** usar os nomes em maiúsculas pedidos e documentar a correspondência em `docs/README.md`.
- **Como evitar:** não criar dois arquivos cujos nomes diferem só em maiúsculas.

### P-002 — Checagem de "existe no registry" do Wally não é confiável por HTTP
- **Sintoma:** `wally.run/package/<qualquer-nome>` responde 200, mesmo para pacotes inexistentes.
- **Solução:** consultar o índice oficial (`UpliftGames/wally-index`), que tem uma entrada por pacote, e confirmar com `wally install`.
- **Como evitar:** para verificar um pacote, usar o índice ou o próprio `wally install`, nunca a página web.

### P-003 — O repositório GitHub do ProfileStore não é a fonte que o Wally usa
- **Sintoma:** o código no GitHub (`ISFOR1/ProfileStore`) e o pacote publicado (`lm-loleris/profilestore@1.0.3`) têm o mesmo conteúdo, mas só depois de remover diferenças de final de linha (CRLF vs LF).
- **Solução:** revisar o código **do pacote instalado** (`ServerPackages/_Index/...`), que é o que roda no jogo, e não só o do GitHub.
- **Como evitar:** após cada `wally install` com versão nova, rever o diff do pacote instalado.
- **Hash (LF) de `ProfileStore.luau` 1.0.3:** `ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f`.

### P-004 — Selene não tem o std do TestEZ embutido
- **Sintoma:** `std = "roblox+testez"` falha com "could not find all standard library files: testez". E sem o std, `describe`, `it` e `expect` aparecem como variáveis indefinidas (66 erros).
- **Solução:** manter `std = "roblox"` e colocar `-- selene: allow(undefined_variable)` apenas nos arquivos `tests/**/*.spec.luau`.
- **Como evitar:** não afrouxar a regra no projeto inteiro. A exceção fica restrita aos specs.

### P-005 — Build do Rojo falha se a pasta de saída não existir
- **Sintoma:** `[ERROR rojo] failed to create file ... (os error 3)`.
- **Solução:** criar a pasta antes (`mkdir -p build`). Aplicado no `ci.yml`.
- **Como evitar:** o `.gitignore` ignora `build/`, então a pasta não existe em um clone novo. Todo comando de build deve criá-la antes.

### P-006 — `luau-analyze` sem definições de tipo do Roblox
- **Sintoma:** ao rodar `luau-analyze` nas pastas `src/`, aparecem erros `Unknown global 'game'`, `'task'`, `'warn'`, `'script'`, `'Instance'`, `Unknown type 'Player'`, `'Folder'`, `'Enum.UserInputType'` e `Unknown require: unsupported path`.
- **Causa:** o analisador é o Luau puro. Não conhece a API do Roblox nem os `require()` com caminhos do Roblox.
- **Resultado:** todos os erros restantes são desse tipo, de ambiente. O único erro real encontrado (`Expected this to be 'T', but got 'intersect<T, ~table>'` no `deepCopy` de `DataService`) foi corrigido com tipo `any` explícito.
- **Verificado sem ruído do ambiente:** `SchemaMigrator`, `RateLimiter`, `Validate`, `InputMode`, `Persistence` e `PlayerData` passam sem erros (exit 0).
- **Solução pendente:** incluir as definições de tipo oficiais do Roblox, para que o restante também seja checado. Requer aprovação, pois é um download adicional de terceiros.
- **Como evitar:** não declarar a checagem de tipos completa enquanto houver erros não classificados.

### P-008 — `deepCopy` genérico estreitava o tipo e falhava no strict
- **Sintoma:** `Expected this to be 'T', but got 'intersect<T, ~table>'` na linha de `if type(value) ~= "table"`.
- **Solução:** assinatura `(value: any): any`, com cópia para tabela tipada como `{ [any]: any }`.
- **Como evitar:** em funções utilitárias sobre dados desconhecidos, usar `any` na entrada e na saída, em vez de genéricos com narrowing.

### P-009 — `registry = "test"` no `wally.lock`
- **Observação:** o lock gerado pelo Wally 0.3.2 fixado grava `registry = "test"`, enquanto o `wally.toml` aponta para `https://github.com/UpliftGames/wally-index`. O `wally install` funciona com esse lock.
- **Como evitar:** não editar o `wally.lock` à mão. Se o comportamento mudar em uma atualização do Wally, revisar aqui.

### P-007 — Testes TestEZ não podem rodar no CI
- **Causa:** TestEZ precisa do runtime do Roblox (Studio), que não está disponível em runners padrão do GitHub.
- **Solução adotada:** testes rodam no Studio com `test.project.json`. O CI verifica formatação, lint e builds.
- **Como evitar:** avaliar um runner com Studio (ex.: runner próprio) se a automação de testes for necessária.

### P-010 — Alteração direta de `profile.Data` podia salvar estado parcial
- **Sintoma (auditoria, P1 e P2):** `GetData` devolvia a tabela viva, e `Mutate` alterava `profile.Data` in-place. Um erro no meio da função deixava alterações parciais, que o ProfileStore grava no próximo salvamento.
- **Causa:** o ProfileStore lê `profile.Data` no momento de salvar (`ProfileStore.luau:791`), então qualquer alteração feita antes de uma falha é gravada.
- **Solução:** `GetData` devolve cópia profunda. `Mutate` executa a função numa cópia e só substitui `profile.Data` se terminar sem erro. A troca da tabela é compatível com o ProfileStore 1.0.3, porque o salvamento e o `Reconcile` leem `profile.Data` a cada chamada.
- **Como evitar:** nunca alterar o estado vivo diretamente. Toda escrita passa por `Mutate`, e toda leitura para uso externo recebe cópia.
- **Verificação:** specs em `tests/Logic/Transaction.spec.luau` e `DeepCopy.spec.luau`. Com a mutação direta de volta, 4 casos falham. Testes rodados fora do Studio por harness, e validados no Studio (30 TestEZ aprovados; teste de integração em duas rodadas, sem falhas). Ver `CHANGELOG.md`.

### P-011 — Lock de sessão preso no DataStore de teste
- **Sintoma:** o perfil de teste não carregava: o `StartSessionAsync` ficava tentando, e não havia escrita nem erro visível no início.
- **Causa:** um `ActiveSession` deixado por uma sessão anterior que não liberou o lock. A última atualização do registro ficou parada, então nenhum servidor vivo o renovava.
- **Solução:** aguardar a expiração natural. O ProfileStore 1.0.3 trata o lock como morto após `ASSUME_DEAD` = 630 s sem atualização (`ServerPackages/_Index/.../ProfileStore.luau`). Após a expiração, a sessão carregou normalmente.
- **Decisão:** não remover o lock manualmente nem editar o registro no DataStore. Isso alteraria o estado de sessão à mão, e o próprio mecanismo resolve o caso.
- **Como evitar:** toda sessão de teste deve terminar pelo Stop do Studio (que dispara o `EndSession`). Antes de uma nova sessão, conferir `ActiveSession` no registro. Se houver lock recente, aguardar `ASSUME_DEAD` antes de começar, e não encerrar o Studio de forma forçada durante um teste.
- **Limite:** `START_SESSION_TIMEOUT` = 120 s. Uma tentativa de carregamento com lock ativo falha depois desse tempo.

### P-012 — Leitura do módulo fora do script de teste enganou a verificação
- **Sintoma:** consultas feitas pelo executor do MCP (`DataService.IsLoaded`) mostravam `Loaded=false` enquanto o script de teste, rodando no servidor, registrava o perfil como carregado.
- **Causa provável (não confirmada):** o executor do MCP obtém uma instância do módulo separada da do jogo.
- **Como evitar:** validar o estado do jogo por dentro do próprio jogo (script de teste ou log), e não por `require` a partir do executor externo.
- **Observação:** no modo Edit, a leitura direta do DataStore pelo executor do MCP também falhou, sem causa clara. Ler os registros durante o Play ou pelo próprio script.

### P-013 — Saldo exibido não atualizava após a compra (corrigido)
- **Sintoma (Studio):** a construção era aceita e o saldo no servidor caía, mas a madeira mostrada no cliente continuava igual.
- **Causa:** o `BuildService` não reenviava o saldo depois de uma compra aceita. O snapshot só saía ao carregar o perfil ou coletar.
- **Correção:** após `Ok`, o servidor envia o snapshot (`IslandService.SendSnapshot`). Verificado no Studio: 14 → 12 após a Cerca.
- **Aprendizado de teste:** em tabela literal, `{ OwnerSlot = nil }` não cria a chave. Para testar um campo ausente, atribua `nil` depois de criar o pedido. Um teste TestEZ falhou por isso (não pela regra).

### P-014 — Objetos enterrados: altura do Terrain diferente da preenchida (corrigido)
- **Sintoma (Studio, medido por raycast):** pontos de construção, estruturas e decoração ficaram cerca de 2 studs abaixo do chão, e palmeiras na colina até 4 studs abaixo.
- **Causas:** (1) o Terrain trabalha em células de 4 studs e arredonda a superfície: preencher até y = 0 gerou chão em y = 2, e subir o preenchimento em 2 gerou chão em 6 (não é previsível por conta simples); (2) raycasts feitos logo após `FillCylinder`/`FillBlock` não acertam o terreno novo e caíam no valor padrão.
- **Correção:** o servidor molda o terreno de todas as ilhas, espera o terreno responder a raycasts (`Environment.WaitForGround`) e **mede** o chão real da clareira, que passa a ser a origem da ilha. Palmeiras e decoração usam a altura medida em cada ponto. Verificado: chão em 2,0 em todos os pontos, estruturas e marcadores assentados, nenhuma decoração enterrada.
- **Aprendizado:** nunca supor a altura do Terrain; medir depois de preencher.

### P-015 — Plugin do Rojo desconectado e sincronização manual
- **Sintoma:** após reiniciar o `rojo serve`, o plugin do Studio não reconectou sozinho. O MCP não aciona plugins de terceiros e bloqueia HTTP para `localhost` (lista de permissões do Assistente).
- **Solução usada:** os arquivos alterados foram aplicados ao Studio pelo executor do MCP (mesmo mapeamento do `test.project.json`) e conferidos com **checksum de cada script contra o arquivo do repositório**: todos idênticos. Nada foi salvo no lugar; o repositório continua sendo a fonte.
- **Como evitar:** manter o plugin conectado (botão Connect no painel do Rojo) durante sessões com o Claude.

### P-016 — Captura de tela sem a cena 3D
- **Sintoma:** `screen_capture` mostrou só a interface (fundo vazio do viewport), em Play e também no modo de edição, que não roda o código do jogo. A primeira captura da sessão ("antes") funcionou.
- **Diagnóstico:** testes A/B no cliente sem terreno e sem pós-processamento continuaram sem 3D; a captura do modo de edição expirou. Indica viewport do Studio sem renderizar (janela minimizada ou encoberta), e não um defeito do mundo.
- **Pendente:** capturar o "depois" com o Studio visível. As prévias 3D do painel (`ViewportFrame`) também dependem disso para validação visual.
- **Continuou na entrega da Serraria (2026-11-26):** a imagem 3D final ainda não foi capturada. Ver `CHANGELOG.md`.

### P-017 — `Terrain.GrassLength` não pode ser alterado por script de jogo
- **Sintoma:** ao definir `Terrain.GrassLength` no código do jogo, o `IslandService.Init` falhava e a ilha não era montada.
- **Causa:** a propriedade exige a capacidade `PluginOrOpenCloud`, que scripts de jogo não têm.
- **Solução:** gramado em material `LeafyGrass`, sem grama decorativa alta (D-033).
- **Como evitar:** antes de usar uma propriedade do Terrain ou da engine por código, confirmar no Studio que o script de jogo consegue alterá-la.
- **Observação:** o world-builder deixou `GrassLength = 0.3` no Terrain do lugar em modo Edit, sem salvar. Não afeta o jogo, porque o repositório é a fonte.

### P-018 — Studio usa o UserId real: sem perfil isolado para testar jogador novo (resolvido)
- **Sintoma:** no Play do Studio, o jogador usa o próprio UserId e o perfil já existente. Não há como testar a experiência de jogador novo (orientação, primeira construção) sem alterar o `DataService` ou apagar o perfil.
- **Solução usada:** a experiência de jogador novo foi testada pela lógica pura (`tests/Logic/Onboarding.spec.luau`).
- **Resolução (D-040):** perfil temporário com o atributo `FreshProfile = true` no Workspace, que faz o `DataService` usar `ProfileStore.Mock` (só memória, sem DataStore). Não altera perfis reais.
- **Como evitar:** não apagar perfis de teste para simular jogador novo. Usar `FreshProfile` no Studio.

### P-019 — HTTP local bloqueado no Studio MCP
- **Sintoma:** `execute_luau` não consegue fazer `HttpService` para `127.0.0.1`, então a sincronização por HTTP falha.
- **Causa:** o endereço local está fora da lista de permissões do Assistente (MCP do Studio).
- **Solução:** a sincronização passou a ser pelo `rojo serve` com o botão Connect feito pelo dono no plugin do Rojo.
- **Como evitar:** não tentar HTTP local pelo `execute_luau`. Conferir se o plugin do Rojo está conectado antes de testar (ver P-015).

### P-020 — `require` em `execute_luau` cria outra instância do módulo
- **Sintoma:** consultas feitas por `require` de um serviço no `execute_luau` mostram um estado diferente do que roda no jogo (ver P-012).
- **Causa:** o `require` do executor cria outra instância do módulo, com estado próprio, separada da que o servidor usa.
- **Solução:** inspecionar o estado do servidor pelo Workspace (atributos públicos) ou pelos remotes, e não por `require` dos serviços.
- **Como evitar:** não usar `require` de serviços do servidor para inspecionar estado. Validar por dentro do jogo ou pelos remotes.

### P-021 — Tabela do perfil exposta por `Read` (resolvido)
- **Sintoma:** `DataService.Read` (D-039) devolvia a tabela viva do perfil. Um consumidor podia alterá-la fora de `Mutate`, e a alteração seria salva junto com o perfil (ver P-010).
- **Causa:** `Read` não copiava a tabela, para evitar custo em caminhos frequentes (D-039). Nada impedia a escrita.
- **Solução:** D-046. Os dados são congelados (`DeepCopy.Freeze`) após cada carga e cada `Mutate`, então alterar a tabela gera erro. `Read` roda o leitor numa corrotina, que é encerrada com erro se esperar.
- **Como evitar:** toda escrita passa por `Mutate`. Quem usa `Read` não guarda a referência nem espera dentro do leitor.

### P-022 — Resto de areia ao liberar a expansão (resolvido)
- **Sintoma:** ao liberar a ilha, a área da expansão voltava ao mar, mas ficava um resto de areia junto à praia.
- **Causa:** a limpeza não apagava a faixa de areia que liga a expansão à ilha.
- **Solução:** D-047. A expansão é apagada por inteiro (área e faixa), e a ilha principal é moldada de novo com a mesma semente, voltando ao original.
- **Como evitar:** ao criar terreno dinâmico, registrar todas as partes criadas, não só a área principal, para que a limpeza cubra tudo.

## Aprendizados
- O repositório começou sem commits. Fazer o primeiro commit antes de depender do histórico Git para revisar mudanças.
- Versões de dependências devem ser verificadas nas fontes oficiais (índice do Wally, releases do GitHub) e registradas com hash.
- Arquivos de configuração do Rojo: `init.server.luau` (minúsculo) transforma a pasta em um Script. Diferente de `Init.server.luau`, que ficaria como um filho comum.
- O ProfileStore registra o próprio `game:BindToClose`. Duplicar essa lógica no `DataService` seria redundante.
- Em `DataService`, a versão do schema deve ser verificada antes de qualquer `Reconcile`, porque `Reconcile` altera os dados.
