# Documentação — Island Rebuild

Índice e checklist do projeto. Esta pasta é a memória e a base de conhecimento do projeto.

## Índice

| Arquivo | Função | Equivale a (regra global) |
|---|---|---|
| [GDD.md](GDD.md) | Visão, design, plataformas e modelo de negócio | `visao-geral.md` |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Arquitetura técnica (aprovada) | `arquitetura.md` |
| [decisoes.md](decisoes.md) | Registro de decisões (D-001 a D-022) | `decisoes.md` |
| [problemas-e-aprendizados.md](problemas-e-aprendizados.md) | Bugs, armadilhas e lições (P-001 a P-007) | `problemas-e-aprendizados.md` |
| [ROADMAP.md](ROADMAP.md) | Fases, marcos e checklist da Fase 1 | `roadmap.md` |
| [CHANGELOG.md](CHANGELOG.md) | Histórico de alterações | `changelog.md` |
| [skills-e-ferramentas.md](skills-e-ferramentas.md) | Skills, ferramentas (com versões e sha256) e pacotes | `skills-e-ferramentas.md` |

> Nota: no Windows, `roadmap.md` e `ROADMAP.md` são o mesmo arquivo (o sistema de arquivos não diferencia maiúsculas). Por isso o projeto usa os nomes em maiúsculas pedidos na configuração inicial. Ver P-001.

## Checklist

### Fase 0 — Fundação ✅
- [x] Analisar a estrutura inicial da pasta
- [x] Criar `CLAUDE.md`, `README.md` e a documentação inicial
- [x] Aprovar a arquitetura
- [x] Responder às perguntas de plataforma e monetização

### Fase 1 — Base técnica 🔄
- [x] Rojo, Wally, StyLua, Selene e CI configurados com versões fixadas
- [x] Bootstrap de servidor e cliente
- [x] DataService (ProfileStore), NetService, controle de modo de entrada
- [x] Testes TestEZ escritos e lógica verificada por lint e build
- [x] Checagem `--!strict` nos módulos de lógica pura (luau-analyze oficial). Restante pendente de definições do Roblox (P-006)
- [x] Primeiro commit local (ver `CHANGELOG.md`)
- [ ] Push para o GitHub (aguardando URL e branch)
- [ ] Validação no Studio (perfil, sessão, expulsão, dois clientes, testes TestEZ)
- [ ] Aprovação do dono para encerrar a Fase 1

## Como manter
- Toda tarefa começa lendo esta pasta e termina atualizando o `CHANGELOG.md`.
- Mudança de arquitetura ou regra gera uma entrada em `decisoes.md`.
- Problema resolvido, ou armadilha descoberta, gera uma entrada em `problemas-e-aprendizados.md`.
- Ferramenta ou pacote novo gera uma entrada em `skills-e-ferramentas.md`, com versão e verificação.
