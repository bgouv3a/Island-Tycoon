# Roadmap — Island Rebuild

Legenda: ✅ concluído · 🔄 em andamento · ⏳ aguardando aprovação · ⬜ não iniciado

| Fase | Objetivo | Status |
|---|---|---|
| **0. Fundação** | Documentação, regras e arquitetura | ✅ Concluída (aprovada em 2026-11-24) |
| **1. Base técnica** | Rojo, Wally, bootstrap de servidor e cliente, DataService (ProfileStore), NetService, controles, testes e CI. **Sem gameplay** | 🔄 Código pronto e verificado localmente; validação no Studio pendente |
| **2. Loop de coleta** | Nós de recursos, inventário e economia validados no servidor | ⛔ Não autorizada. Depende da validação da Fase 1 no Studio e de nova aprovação |
| **3. Construção** | Colocação de estruturas e lotes de ilha | ⬜ |
| **4. Automação** | Máquinas de produção com agendamento centralizado | ⬜ |
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
- [ ] Push para o GitHub (aguardando URL do repositório e branch)
- [ ] Validar no Studio: carregamento de perfil, lock de sessão, expulsão e encerramento
- [ ] Validar no Studio com dois clientes: sessão roubada e saída durante o carregamento
- [ ] Executar os testes TestEZ no Studio
- [ ] Confirmar no Studio a separação entre projeto de produção e projeto de testes
- [ ] Aprovação do dono para encerrar a Fase 1 e iniciar a Fase 2

## Próximos passos
1. Informar a URL do repositório GitHub e a branch para o push.
2. Executar o checklist de validação no Studio (itens acima). Requer o Roblox Studio.
3. Corrigir o que falhar, registrando em `problemas-e-aprendizados.md`.
4. Só após a validação, solicitar aprovação para implementar recursos, inventário e economia (Fase 2).

## Critérios de saída de cada fase
- Funcionalidades testadas no Studio com pelo menos dois clientes quando envolverem multiplayer.
- Documentação atualizada e entrada no `CHANGELOG.md`.
- Nenhuma regra de segurança da `ARCHITECTURE.md` violada.
