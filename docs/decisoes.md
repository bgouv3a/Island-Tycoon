# Decisões — Island Rebuild

Formato: cada decisão tem ID, data, status e motivo. Decisões não são apagadas. Quando mudam, ganham uma nova entrada que substitui a anterior, e a antiga fica marcada como "Substituída por D-XXX".

| ID | Data | Decisão | Status | Motivo |
|---|---|---|---|---|
| D-001 | 2026-11-24 | Documentar o projeto e aprovar a arquitetura antes de implementar qualquer sistema de gameplay | Aceita | Pedido do dono do projeto |
| D-002 | 2026-11-24 | Economia e inventário validados somente pelo servidor. O cliente envia intenções, nunca resultados | Aceita | Regra obrigatória; prevenção de exploits |
| D-003 | 2026-11-24 | Separação em `src/server`, `src/client` e `src/shared`, mapeados pelo Rojo | Aceita | Regra obrigatória; clareza de responsabilidades |
| D-004 | 2026-11-24 | Documentação em português do Brasil | Aceita | Preferência do usuário |
| D-005 | 2026-11-24 | Stack: Luau `--!strict`, Roblox Studio, Rojo, Wally, Selene, StyLua, TestEZ, Git e GitHub com CI | Aceita | Aprovado pelo dono do projeto |
| D-006 | 2026-11-24 | Ilhas: lotes individuais no mesmo servidor. Visitas e interações entre jogadores são previstas. O número de jogadores por servidor será definido por testes de desempenho | Aceita | Aprovado. Facilita a interação social |
| D-007 | 2026-11-24 | Persistência com ProfileStore (sessão com lock, versão de schema e migrações) | Aceita | Aprovado |
| D-008 | 2026-11-24 | ProfileStore acessado somente pelo `DataService`. Nenhum outro serviço importa a biblioteca | Aceita | Aprovado. Isola a dependência e centraliza tratamento de falhas |
| D-009 | 2026-11-24 | Dependências com versão exata (`=`), sem atualização automática: `lm-loleris/profilestore@=1.0.3` e `roblox/testez@=0.4.1` | Aceita | Aprovado. Versões verificadas no índice oficial do Wally e revisadas |
| D-010 | 2026-11-24 | Wally com o mínimo de dependências: somente ProfileStore (runtime) e TestEZ (desenvolvimento) | Aceita | Aprovado. "Somente dependências realmente necessárias" |
| D-011 | 2026-11-24 | Dois projetos Rojo: `default.project.json` (produção, sem testes nem TestEZ) e `test.project.json` (Studio, com testes) | Aceita | Evita enviar código de teste ao jogo final. Verificado: o build de produção não contém testes |
| D-012 | 2026-11-24 | Plataformas: PC e mobile desde o MVP. Arquitetura de controles preparada para consoles, sem atrasar o lançamento | Aceita | Aprovado |
| D-013 | 2026-11-24 | Modelo de negócio: jogo gratuito. Cosméticos, personalização e conveniências opcionais no futuro, sem vantagens que quebrem o equilíbrio da progressão | Aceita | Aprovado |
| D-014 | 2026-11-24 | Monetização implementada somente após o núcleo do jogo estar funcional e divertido | Aceita | Aprovado |
| D-015 | 2026-11-24 | Automação: um sistema centralizado que respeita o intervalo individual de cada máquina (agendamento por horário de próxima produção, não um loop por máquina) | Aceita | Aprovado. Desempenho com escala e precisão por máquina |
| D-016 | 2026-11-24 | Studio usa um DataStore separado (`IslandRebuild_PlayerData_Studio`) | Aceita | Testes no Studio não alteram dados reais de produção |
| D-017 | 2026-11-24 | Dados de versão mais nova ou inválida nunca são alterados pelo código (status `TooNew`/`Invalid`) | Aceita | Protege contra perda de dados em rollback de versão |
| D-018 | 2026-11-24 | Migrações rodam sobre uma cópia dos dados. Se falharem, nada parcial é gravado | Aceita | Protege contra corrupção por migração interrompida |
| D-019 | 2026-11-24 | Controles e interface são classificados por modo de entrada (`Touch`, `KeyboardMouse`, `Gamepad`), não por plataforma | Aceita | Caminho único para mobile e console |
| D-020 | 2026-11-24 | CI verifica o sha256 de cada ferramenta antes de executá-la | Aceita | Evita executar binário adulterado ou trocado |
| D-021 | 2026-11-24 | Testes de lógica pura rodam no Studio com TestEZ. O CI não executa testes porque não há runtime do Roblox | Aceita | Limitação técnica. Ver `problemas-e-aprendizados.md` |
| D-022 | 2026-11-24 | Fase 1 sem gameplay: só base técnica (bootstrap, persistência, rede, validação, controles, testes e CI) | Aceita | Pedido do dono do projeto |

## Perguntas em aberto
Nenhuma decisão de arquitetura pendente. Pendências que dependem de execução:
- Validar no Roblox Studio o bootstrap, o carregamento de perfil e o encerramento de sessão (Fase 1).
- Confirmar o limite de jogadores por servidor por meio de testes de desempenho (Fase 7).
- Definir o layout de UI responsiva antes da Fase 2 (escala relativa, Scale e não Offset).
