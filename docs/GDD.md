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
| Economia | 2 | Moedas ganhas e gastas, validadas no servidor. **Provisória (2026-11-27):** Pedra, moedas, mercado no píer, melhorias da Serraria, primeira expansão, objetivos iniciais, cadeias produtivas (Pedreira, Carpintaria e tábuas), pedidos comerciais e estágio 2 (Ilha produtiva). Valores em D-034 e D-042 (sujeitos a balanceamento) |
| Construção | 3 | Colocação de estruturas na ilha, com regras de espaço e custo |
| Ilhas | 3 | Um lote por jogador, com área delimitada |
| Automação | 4 | Máquinas que produzem itens em intervalos próprios. Começou antecipadamente com a Serraria (D-031), seguida por Pedreira e Carpintaria (D-041, D-042) |
| Progressão | 5 | Desbloqueios ligados a metas de coleta, construção e automação. Estágio 2 (Ilha produtiva) antecipado como provisório (D-044) |
| Social | 6 | Visitar ilhas de outros jogadores |

## 5. Estilo visual
- Low-poly estilizado, **tropical**, com paleta colorida e clara (`Shared/Art/Palette`). Formas arredondadas e silhuetas reconhecíveis (palmeiras, cabanas, píer).
- Ilha com contorno natural: praia, grama, colina, clareira de construção e caminho. Frente da ilha com píer e chegada.
- Interface clara e quente: painéis creme, contorno laranja, botões verdes de ação, fonte arredondada (FredokaOne). Ícones desenhados, sem emoji.
- Feedback a cada ação: popup, partículas, som e animação.
- Otimização desde o início: poucos objetos, poucas luzes dinâmicas e custo de renderização controlado. Visual gerado por código (D-027).

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
1. Quais recursos e cadeias de produção fazem parte do MVP? *(necessário antes da Fase 2)*. **Parcial:** recursos provisórios são Madeira (D-024), Pedra e Moedas (D-034, D-035) e Tábuas (D-042). Cadeias provisórias: Pedreira (pedra) e Carpintaria (madeira → tábua), D-041 e D-042. Falta confirmar o conjunto final do MVP.
2. Qual é o limite de jogadores por servidor desejado? *(será definido por testes de desempenho, Fase 7)*
3. Trocas entre jogadores fazem parte do escopo? *(não definido)*
