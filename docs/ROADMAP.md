# Roadmap — Island Rebuild

Legenda: ✅ concluído · 🔄 em andamento · ⏳ aguardando aprovação · ⬜ não iniciado

| Fase | Objetivo | Status |
|---|---|---|
| **0. Fundação** | Documentação, regras e arquitetura | ✅ Concluída (aprovada em 2026-11-24) |
| **1. Base técnica** | Rojo, Wally, bootstrap de servidor e cliente, DataService (ProfileStore), NetService, controles, testes e CI. **Sem gameplay** | 🔄 Código no GitHub e validado no Studio em parte: testes TestEZ (30 aprovados), carregamento, `GetData`, `Mutate`, persistência entre sessões e liberação de lock. Pendentes: expulsão, falhas de carregamento, dois clientes e separação entre produção e teste |
| **2. Loop de coleta** | Nós de recursos, inventário e economia validados no servidor | 🔄 Iniciada por pedido do dono (2026-11-25). Entregue: ilha por jogador, coleta de madeira com saldo persistido e **construção** em pontos fixos com Cerca e Cabana (2026-11-26, pedido do dono). **Vertical slice visual** da ilha inicial (cenário, modelos, interface, feedback e orientação, D-027 a D-030). **Serraria**, primeira automação (2026-11-26, D-031): produção só online, estoque em `Storage`, pontos B5–B8 (D-032). **Economia provisória** (2026-11-27, D-034 a D-040): Pedra, moedas e mercado no píer, melhorias da Serraria (nv1–5), primeira expansão (Enseada Leste) e 8 objetivos com recompensas do servidor. Valores em `Config/Economy` (D-034). Pendente: validação no Studio das novas funções (P-019), validação com dois jogadores, inventário e cadeias de produção (ex.: tábuas na Serraria) |
| **3. Construção** | Colocação de estruturas e lotes de ilha | ⬜ |
| **4. Automação** | Máquinas de produção com agendamento centralizado | ⬜ Primeira máquina antecipada a pedido do dono: Serraria, entregue na Fase 2 (D-031). Demais máquinas e agendamento centralizado não iniciados |
| **5. Progressão** | Desbloqueios e metas | ⬜ |
| **6. Social** | Visitas e interações entre ilhas | ⬜ |
| **7. Polimento e desempenho** | Testes de desempenho (define jogadores por servidor), otimização, testes com múltiplos jogadores | ⬜ |
| **8. Monetização** | Somente após o núcleo ser funcional e divertido (D-014) | ⬜ |

## Checklist da Fase 1
- [x] `default.project.json` (produção) e `test.project.json` (teste)
- [x] Wally com `ProfileStore =1.0.3` e `TestEZ =0.4.1`, `wally.lock` gerado
- [x] StyLua, Selene e CI configurados
- [x] Bootstrap do servidor (`init.server.luau`) e do cliente (`init.client.luau`)
- [x] DataService: única camada que usa o ProfileStore
- [x] NetService: rate limit, validação e handler para remotes
- [x] Lógica pura: SchemaMigrator, RateLimiter, Validate, InputMode, com testes TestEZ escritos
- [x] Controle de modo de entrada (toque, teclado/mouse, gamepad)
- [x] Formatação, lint e builds verificados localmente
- [x] Checagem `--!strict` (luau-analyze 0.748 oficial): módulos de lógica pura sem erros; o restante só tem erros de ambiente por falta das definições de tipo do Roblox (P-006)
- [x] Primeiro commit local da Fase 1 (hash no `CHANGELOG.md`)
- [x] Push para a branch `fase-1-base-tecnica` no GitHub (`main` preservada)
- [x] Correção P1 e P2 da auditoria: `GetData` e `Mutate` seguros (D-023, P-010). Validados no Studio (rodadas 1 e 2, ver `CHANGELOG.md`)
- [ ] Validar no Studio: carregamento, persistência entre sessões e liberação de lock validados. **Pendentes:** expulsão por `TooNew`/`Invalid`, falha de migração e falha de carregamento (P-011)
- [ ] Validar no Studio com dois clientes: sessão roubada e saída durante o carregamento
- [x] Executar os testes TestEZ no Studio (30 aprovados, 0 falhas)
- [ ] Confirmar no Studio a separação entre projeto de produção e projeto de testes
- [ ] Aprovação do dono para encerrar a Fase 1 e iniciar a Fase 2

## Próximos passos
1. Executar os itens pendentes do checklist no Studio: expulsão, falhas de carregamento, dois clientes e separação entre produção e teste. Requer o Roblox Studio.
2. Corrigir o que falhar, registrando em `problemas-e-aprendizados.md`.
3. Só após a validação, solicitar aprovação para encerrar a Fase 1 e, depois disso, implementar recursos, inventário e economia (Fase 2).

## Próximos passos da Fase 2 (economia provisória)
1. **Cadeia de tábuas (Planks) na Serraria:** transformar madeira em tábuas. Exige aprovação de design antes da implementação.
2. **Balanceamento com jogadores:** ajustar os valores de `Config/Economy` (D-034) com teste de pelo menos dois clientes.
3. **Mais expansões:** definir as próximas áreas e seus custos. Exige aprovação de design.

## Critérios de saída de cada fase
- Funcionalidades testadas no Studio com pelo menos dois clientes quando envolverem multiplayer.
- Documentação atualizada e entrada no `CHANGELOG.md`.
- Nenhuma regra de segurança da `ARCHITECTURE.md` violada.
