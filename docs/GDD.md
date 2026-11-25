# GDD — Island Rebuild

> Status: visão e plataformas **aprovadas** em 2026-11-24. Os sistemas de gameplay ainda não foram implementados e exigem aprovação de cada um antes da implementação.

## 1. Conceito
Simulador e tycoon para Roblox. O jogador começa com uma ilha pequena e danificada e a reconstrói: coleta recursos, constrói estruturas e automatiza a produção. Cada jogador tem a própria ilha, e as ilhas se conectam socialmente.

## 2. Pilares de design
1. **Coleta** — recursos visíveis no mundo, coletados com ações simples e feedback claro.
2. **Construção** — o jogador coloca estruturas na própria ilha, e a ilha cresce visualmente.
3. **Automação** — máquinas produzem sozinhas, reduzindo o trabalho manual e liberando decisões de expansão.
4. **Ilha própria** — espaço pessoal, com identidade visual e progresso próprio.
5. **Social** — visitar ilhas de outros jogadores e interagir com eles.

## 3. Loop principal *(proposta, a detalhar por fase)*
```
Coletar recursos → Processar/vender → Comprar ou construir → Automatizar → Expandir a ilha → (repete, com mais recursos)
```

## 4. Sistemas previstos *(por fase, cada um sujeito a aprovação)*
| Sistema | Fase | Descrição resumida |
|---|---|---|
| Base técnica (bootstrap, persistência, rede, validação) | 1 | Sem gameplay visível |
| Recursos e coleta | 2 | Nós de recursos no mundo que reaparecem após um tempo |
| Inventário | 2 | Itens do jogador, com limite e validação no servidor |
| Economia | 2 | Moedas ganhas e gastas, validadas no servidor |
| Construção | 3 | Colocação de estruturas na ilha, com regras de espaço e custo |
| Ilhas | 3 | Um lote por jogador, com área delimitada |
| Automação | 4 | Máquinas que produzem itens em intervalos próprios |
| Progressão | 5 | Desbloqueios ligados a metas de coleta, construção e automação |
| Social | 6 | Visitar ilhas de outros jogadores |

## 5. Estilo visual
- Low-poly, com paleta colorida e clara.
- Otimização desde o início: poucos objetos, poucas luzes dinâmicas e custo de renderização controlado.

## 6. Plataformas (aprovado)
- **PC e mobile desde o MVP.** Controles e interface são projetados para os dois.
- **Consoles:** a arquitetura de controles e interface deve permitir a compatibilidade no futuro, sem atrasar o lançamento inicial.

## 7. Modelo de negócio (aprovado)
- **Jogo gratuito.**
- No futuro, podem ser adicionados itens cosméticos, personalizações e conveniências opcionais.
- **Não haverá vantagens pagas que prejudiquem o equilíbrio da progressão.**
- A monetização será implementada **somente depois que o núcleo do jogo estiver funcional e divertido**.

## 8. Fora de escopo por enquanto
- Monetização de qualquer tipo (ver seção 7 para as diretrizes).
- Trocas diretas entre jogadores e mercado global: **não definidos**. Não implementar sem aprovação.

## Perguntas em aberto
1. Quais recursos e cadeias de produção fazem parte do MVP? *(necessário antes da Fase 2)*
2. Qual é o limite de jogadores por servidor desejado? *(será definido por testes de desempenho, Fase 7)*
3. Trocas entre jogadores fazem parte do escopo? *(não definido)*
