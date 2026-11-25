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

## Aprendizados
- O repositório começou sem commits. Fazer o primeiro commit antes de depender do histórico Git para revisar mudanças.
- Versões de dependências devem ser verificadas nas fontes oficiais (índice do Wally, releases do GitHub) e registradas com hash.
- Arquivos de configuração do Rojo: `init.server.luau` (minúsculo) transforma a pasta em um Script. Diferente de `Init.server.luau`, que ficaria como um filho comum.
- O ProfileStore registra o próprio `game:BindToClose`. Duplicar essa lógica no `DataService` seria redundante.
- Em `DataService`, a versão do schema deve ser verificada antes de qualquer `Reconcile`, porque `Reconcile` altera os dados.
