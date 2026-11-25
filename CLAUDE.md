# Island Rebuild — instruções para o Claude

Jogo **Simulator + Tycoon** para **Roblox**, em **Luau**. Projeto comercial desenvolvido por uma pessoa com apoio de IA.
Estilo: low-poly, colorido e otimizado. Gameplay: coleta, construção e automação. Multiplayer com ilhas individuais e interação social.
Plataformas: PC e mobile no MVP; arquitetura preparada para consoles. Jogo gratuito.

Você atua como engenheiro de software principal: planeja a arquitetura, escreve código Luau modular, revisa segurança e desempenho, cria documentação e testa.

## Estado atual
- **Fase 1 (base técnica) em andamento. Sem gameplay.** A arquitetura foi aprovada (ver `docs/decisoes.md`).
- Não implementar sistemas de gameplay (coleta, economia, construção, automação etc.) antes da aprovação da fase correspondente em `docs/ROADMAP.md`.
- Pendências de validação: testes no Studio e checagem `--!strict` (ver `docs/ROADMAP.md`).

## Regras obrigatórias
1. Não modificar sistemas importantes sem aprovação explícita do dono do projeto.
2. Não excluir arquivos sem autorização. Antes de sobrescrever ou apagar, verificar o conteúdo.
3. Não substituir código funcional sem analisar e apresentar os impactos antes.
4. Economia e inventário são **validados somente pelo servidor**. O cliente envia apenas intenções, nunca resultados.
5. Separar cliente e servidor: `src/server` (servidor), `src/client` (cliente), `src/shared` (ambos, sem dependências de servidor ou cliente).
6. **Persistência:** somente o `DataService` usa o ProfileStore. Nenhum outro serviço faz `require` da biblioteca.
7. **Dependências:** versões exatas (`=`) no `wally.toml`. Nenhuma dependência nova sem aprovação; manter o mínimo possível.
8. **Luau:** todo arquivo começa com `--!strict`.
9. Toda alteração é documentada em `docs/`.
10. Não inventar funcionalidades fora do `docs/GDD.md`. Dúvidas viram perguntas em "Perguntas em aberto".
11. Priorizar código simples, modular e escalável.
12. Evitar duplicação de sistemas: antes de criar algo novo, procurar o existente e consultar `docs/ARCHITECTURE.md`.

## Comandos do projeto
```
wally install                                  # instala dependências (Packages, ServerPackages, DevPackages)
stylua --check src tests                       # verifica formatação (stylua src tests para aplicar)
selene src tests                               # lint
rojo build default.project.json -o build/game.rbxlx   # build de produção (antes: mkdir -p build)
rojo serve test.project.json                   # Studio com testes (TestEZ)
```
Ferramentas e versões: ver `docs/skills-e-ferramentas.md`.

## Documentação (regra global do usuário)
- **Antes de cada tarefa:** ler `docs/README.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md` e `docs/decisoes.md`.
- **Ao fim de cada tarefa:** atualizar `docs/CHANGELOG.md` sempre; e `docs/decisoes.md`, `docs/problemas-e-aprendizados.md`, `docs/ROADMAP.md`, `docs/ARCHITECTURE.md` e `docs/GDD.md` quando houver mudança.
- Nunca registrar chaves de API, tokens ou senhas em nenhum arquivo, inclusive na documentação.

## Idioma
- Responder e escrever documentação em **português do Brasil**. Código, nomes de serviços e APIs do Roblox seguem o padrão em inglês.

## Skills e ferramentas
- Plugin `roblox-dev` instalado: usar as skills `roblox-*` ao escrever ou revisar código Roblox (segurança de remotes, DataStore, performance, tipagem strict).
- Skill `find-skills` disponível globalmente: buscar com `npx -y skills find <termo>`. **Revisar a origem e pedir aval do usuário antes de instalar** qualquer skill.
- Todo skill ou ferramenta instalada deve ser registrada em `docs/skills-e-ferramentas.md`.
