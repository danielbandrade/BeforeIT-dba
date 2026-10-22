# O que falta no plano de pesquisa à luz de Brusatin et al. (2024)

Diagnóstico da versão atual de [`plano-de-pesquisa.tex`](./plano-de-pesquisa.tex), considerando *Simulating the Economic Impact of Rationality through Reinforcement Learning and Agent-Based Modelling*, de Brusatin et al. (2024), [DOI: 10.1145/3677052.3698621](https://doi.org/10.1145/3677052.3698621). As páginas citadas abaixo são as páginas impressas do artigo (159–167). O artigo é fonte de evidência e comparação; seus procedimentos e números não são instruções para este projeto.

## Diagnóstico central

O plano tem um objeto promissor e já delimita o modelo, quatro instrumentos fiscais, referências de déficit e dívida e um horizonte inicial de 12 trimestres. Falta transformar esses elementos em um experimento que permita responder, sem ambiguidade, se a **adaptação da política** melhora os resultados em relação a uma **boa política fixa**.

| Dimensão | Brusatin et al. (2024) | Proposta atual |
|---|---|---|
| Modelo | R-MABM, extensão do CC-MABM | BeforeIT.jl calibrado para a Áustria |
| Agente que aprende | Firmas produtoras de bens de consumo | Governo |
| Decisões | Preço e quantidade desejada | Imposto de renda, IVA, benefício de desemprego e gasto do governo |
| Recompensa | Lucro da firma, com penalidade por falência | Índice que combina PIB, desemprego, inflação, mudança de política, déficit e dívida |
| Pergunta empírica | Efeitos de firmas que aprendem sobre desempenho e estabilidade | Ganho de uma política fiscal que reage ao estado da economia |

O artigo especifica observações, ações, recompensa, algoritmo, episódios e testes (pp. 161–163). Ele mostra que melhorar o objetivo dos agentes ou mesmo o PIB médio não garante maior estabilidade macroeconômica (pp. 164–165). Nas conclusões, indica agentes governamentais como possível extensão (p. 166). Isso **motiva** o estudo, mas não demonstra que políticas governamentais com aprendizagem por reforço nunca foram estudadas; o próprio artigo menciona trabalhos relacionados sobre desenho de políticas. A contribuição precisa ser delimitada pela combinação **BeforeIT.jl + governo fiscal adaptativo + comparação controlada + referências fiscais + avaliação de estabilidade**, após ampliar a revisão de literatura.

## Prioridade 1 — decisões sem as quais a proposta não fica testável

### 1. Fixar a pergunta, o resultado principal e as hipóteses

**Onde:** pergunta central e secundárias (linhas 52–63); objetivos (75–89).

- [ ] Definir se “bem-estar” significa uma medida econômica substantiva ou apenas a função de recompensa construída pelo pesquisador. PIB, desemprego e inflação formam um **índice de desempenho macroeconômico**, não uma medida inequívoca de bem-estar social. Se o termo “bem-estar” for mantido, justificar seus componentes e limitações.
- [ ] Formular a hipótese principal como ganho **fora da amostra** da política adaptativa contra a melhor política fixa encontrada com os mesmos instrumentos, horizonte e função objetivo. A comparação somente com a calibração original é fraca: qualquer ganho poderia vir de escolher parâmetros melhores, sem contribuição da adaptação.
- [ ] Separar hipóteses de desempenho, conformidade fiscal e estabilidade. Uma política pode elevar a recompensa média e ao mesmo tempo aumentar a frequência de déficit acima de 3% ou a volatilidade do PIB, como alerta o tipo de resultado encontrado por Brusatin et al. (p. 165).
- [ ] Tornar as perguntas secundárias respondíveis: indicar quais efeitos da sensibilidade serão estimados, como será medida a precisão do metamodelo e em quais cenários a política será comparada. A terceira pergunta hoje diz “regras fixas e políticas fiscais”, expressão que não identifica comparadores.

**Formulação possível para a pergunta central:** “No BeforeIT.jl calibrado para a Áustria, uma política fiscal adaptativa treinada por aprendizagem por reforço melhora o índice de desempenho macroeconômico definido no estudo em relação a políticas fiscais fixas otimizadas, sem aumentar a frequência ou a magnitude dos desvios das referências de déficit e dívida?” A pergunta pode ser ajustada depois de decidir se os desvios fiscais serão restrições rígidas ou apenas resultados avaliados.

### 2. Especificar o problema de aprendizagem por reforço

**Onde:** equação da política (162–170) e seção de recompensa (235–271).

- [ ] Definir o vetor de **observações** efetivamente disponível ao governo *antes* de escolher a ação: por exemplo, desemprego, inflação, crescimento, déficit e dívida publicados até o trimestre anterior e a política vigente. A entrada atual é todo o estado microscópico `x`, que não é uma informação governamental plausível nem uma entrada operacional para o agente. Dizer se essa observação resumida é suficiente para tratar o problema como Markoviano; se não, reconhecer a observação parcial.
- [ ] Definir o **momento da decisão**: observação no fim de `t−1`, escolha e aplicação de `p_t`, simulação do trimestre `t`, cálculo da recompensa, atualização do agente. Esclarecer quando os indicadores fiscais se tornam observáveis.
- [ ] Fixar **intervalos admissíveis, passo máximo e frequência de alteração** para cada uma das quatro alavancas, assim como a política inicial. A notação `p ∈ P` ainda não define `P`. Diferenciar nível absoluto, variação relativa e logaritmo do multiplicador de gasto.
- [ ] Confirmar que o BeforeIT.jl aceita a atualização trimestral de **cada** instrumento, especialmente o IVA, e que impostos, transferências, gastos, déficit e dívida continuam contabilmente coerentes após as alterações. Documentar o mapeamento entre ação do agente e parâmetro do simulador.
- [ ] Definir a **unidade de treinamento**: episódio, número de trimestres, estado inicial, sorteios, choques, aquecimento e reinicialização entre episódios. Doze trimestres podem ser curtos para avaliar dívida e recuperação de choques; justificar esse horizonte ou prever avaliação mais longa.
- [ ] Escolher uma família de algoritmo compatível com observações e quatro controles ou estabelecer critério explícito para escolhê-la. No artigo, Q-learning tabular é viável porque observações e ações são discretizadas e pequenas (p. 162); copiar o algoritmo sem justificar a discretização dos quatro instrumentos ampliaria muito o espaço de ações. Informar estratégia de exploração, objetivo acumulado/desconto e critérios de parada, ainda que os hiperparâmetros sejam ajustados depois.
- [ ] Esclarecer se a política é treinada somente na escala 1:1000, também na 1:1, ou se existe uma etapa de ajuste na escala integral. O plano atualmente promete “reproduzir” tudo em 1:1 sem definir custo ou critério de transferência.

O artigo usa **100 episódios de treino, 20 de teste, 5.000 passos e 300 passos de aquecimento** para seu próprio modelo e suas firmas (tabela 1, p. 162). Esses números não são uma estimativa de orçamento para 12 trimestres de política fiscal no BeforeIT.jl. Aqui, o número de episódios deve ser estimado com tempo por simulação, curvas de aprendizagem e precisão desejada na avaliação final.

### 3. Fechar a definição econômica da recompensa e das referências fiscais

**Onde:** linhas 235–271 e 273–296.

- [ ] Explicar a escolha de cada termo da recompensa e **normalizar escalas**. Sem isso, os pesos não exprimem uma troca interpretável entre crescimento, desemprego, inflação, alterações de política e desvios fiscais. A análise de sensibilidade informa a escala e a resposta das saídas; ela, sozinha, **não determina a preferência social** entre objetivos.
- [ ] Estabelecer um procedimento para os pesos: padronizar componentes em uma amostra de políticas fixas, escolher um cenário principal justificável, treinar com esses pesos congelados e fazer análise de robustez em alguns conjuntos alternativos. Evitar selecionar pesos com base no conjunto final de teste.
- [ ] Indicar a fonte e a unidade de `π*`: inflação trimestral, anualizada ou acumulada em quatro trimestres. Definir também se o PIB real entra como nível relativo ao início, crescimento trimestral ou valor acumulado. A forma atual `log(Y_t/Y_0)` recompensa repetidamente o nível do PIB ao longo do episódio; isso pode ser intencional, mas precisa ser dito.
- [ ] Especificar o objetivo de treinamento `E[Σ_t δ^(t−1) r_t]` ou seu equivalente, com horizonte e fator de desconto `δ`. O artigo faz isso explicitamente para os lucros das firmas (p. 162). O plano define a recompensa por trimestre, mas não o retorno que o agente maximiza.
- [ ] Definir contabilmente déficit e dívida no BeforeIT.jl: saldo primário ou total, sinal do déficit, estoque da dívida, PIB nominal compatível com cada razão e tratamento dos primeiros quatro trimestres. Verificar que as séries usadas na recompensa e na avaliação são as mesmas.
- [ ] Justificar a trajetória `b_t^meta` acima de 60%: ela incorpora uma redução de **1/20 da distância por ano**, além do limiar de 60%. Se a intenção é usar apenas os benchmarks de Dosi/Dawid, essa trajetória é uma escolha metodológica adicional e precisa de motivo, sensibilidade e horizonte adequado. Os 3%/60% vêm da discussão de regras fiscais por Dosi et al., apresentada em Dawid e Delli Gatti, **não** do artigo de Brusatin.
- [ ] Decidir se déficit e dívida são **penalidades suaves** ou **restrições**. Estarem na recompensa não garante cumprimento: o agente pode aceitar ultrapassá-las se outros ganhos compensarem as penalidades. Se cumprimento for requisito, definir explicitamente limites de ação, restrição probabilística, filtro de segurança ou critério de rejeição. Em qualquer opção, relatar os desvios observados separadamente da recompensa.

### 4. Definir comparadores justos e avaliação estatística

**Onde:** pergunta central (56), método (172–298) e plano de atividades (324–325).

- [ ] Comparar, no mínimo, com a política fiscal original/calibrada e com a **melhor política fixa** encontrada por busca no mesmo conjunto admissível `P` e avaliada pela mesma função objetivo. Um metamodelo validado pode baratear essa busca, desde que a política escolhida seja reavaliada no simulador.
- [ ] Declarar o orçamento de busca/ajuste dos comparadores e do agente adaptativo, para que uma diferença não reflita apenas muito mais esforço de otimização em uma das alternativas.
- [ ] Reservar sementes e cenários separados para **seleção de parâmetros**, **treinamento/ajuste** e **teste final**. Usar as mesmas sementes de teste para comparar políticas, mas não reaproveitar no treino. Informar quantas inicializações independentes do agente serão avaliadas.
- [ ] Pré-definir indicadores finais além do escalar de recompensa: PIB real, desemprego, inflação, déficit/PIB, dívida/PIB, volatilidade do PIB, frequência e tamanho dos excessos fiscais, mudanças de instrumento e tempo de recuperação após choque.
- [ ] Comparar diferenças pareadas por semente/cenário, com tamanho de efeito e intervalo de incerteza. A expressão “estatisticamente significantes” na pergunta secundária exige hipótese, unidade de repetição e método; desvios padrão dos episódios, como os gráficos do artigo (p. 165), são informação descritiva, não teste suficiente por si sós.
- [ ] Testar cenários sem choque e com choques predefinidos, além de condições iniciais plausíveis distintas, se possível. Analisar trajetórias de ações para explicar *como* a política reage, não apenas se o escore sobe. A distinção entre produto médio, volatilidade e resposta a choques é uma das contribuições empíricas mais úteis do artigo (pp. 164–165).

### 5. Delimitar o papel do metamodelo

**Onde:** objetivos específicos (86), treinamento do metamodelo (198–233) e equações de ligação (273–296).

- [ ] Escolher um papel principal **consistente com os dados propostos**: sensibilidade, interpretação e busca da melhor **política fixa**. O metamodelo atual recebe `p` constante e prevê indicadores em `T=12`; por isso não conhece transições induzidas por uma sequência de ações adaptativas.
- [ ] **Reformular ou retirar a imposição** `p_t = p* + Δφ(x_{t−1})`. Ela amarra artificialmente a política adaptativa à solução fixa e não decorre do aprendizado de `h(p)`. `p*` pode ser um comparador fixo forte e, se fizer sentido, uma inicialização opcional; a política adaptativa pode ser treinada diretamente no simulador.
- [ ] Se o objetivo for treinar a política **dentro** de um metamodelo, propor outro objeto: um emulador dinâmico de transições condicionado à observação e à ação, treinado com **sequências de políticas variáveis**, com validação de trajetórias fora da amostra e checagem final no BeforeIT.jl. Isso é um projeto adicional, com risco de erro acumulado; não está sustentado pelas equações de metamodelo estático atuais.
- [ ] Alinhar alvo e figura dos resultados parciais: o texto define previsão do **vetor no trimestre final**, enquanto a figura mostra **trajetórias**. Se há um emulador de trajetórias já construído, sua definição, dados e validação devem aparecer no método; se não, apresentar a figura como teste exploratório distinto.
- [ ] Definir partição de treino/validação/teste por **configuração fiscal** (sem vazamento de sementes da mesma configuração), métricas por indicador, incerteza e critério mínimo de utilidade. O metamodelo precisa ser preciso o bastante para ordenar políticas fixas e sua escolha precisa ser confirmada no simulador, não apenas ter erro médio baixo.

## Prioridade 2 — reforçar a argumentação e a execução

### 6. Reconstruir a revisão bibliográfica como comparação, não lista de citações

**Onde:** linhas 91–101; introdução 44–50; justificativa 65–73.

- [ ] Dedicar um parágrafo a Brusatin et al.: **quem aprende, o que observa, o que controla, o que maximiza, como testa e o que encontrou**. Explicar que sua extensão sugerida ao governo é uma motivação, enquanto o presente estudo usa outro modelo e pergunta fiscal.
- [ ] Distinguir os trabalhos de desenho de tributação ou política por RL, como Zheng et al., da literatura de firmas adaptativas em ABMs e da literatura de regras fiscais de Dosi/Dawid. Não afirmar ineditismo amplo sem uma busca bibliográfica específica.
- [ ] Explicar por que a calibração austríaca e os instrumentos do BeforeIT.jl tornam a pergunta nova e relevante, e quais limitações de validade externa persistem. A justificativa atual explica a utilidade geral dos ABMs, mas pouco diz sobre a lacuna científica específica.
- [ ] Descrever a contribuição esperada em três partes verificáveis: protocolo fiscal no BeforeIT.jl, evidência de ganho ou ausência de ganho contra políticas fixas fortes e diagnóstico dos compromissos entre desempenho, disciplina fiscal e estabilidade. Um resultado nulo também responde à pergunta.

### 7. Planejar o custo computacional e critérios de passagem de escala

**Onde:** amostragem `N × J` (172–196), 1:1000 → 1:1 (298), cronograma (301–331).

- [ ] Medir o tempo de uma simulação por escala e usar isso para orçar amostragem do metamodelo, treino por episódio, repetições de treinamento e teste final. Registrar `N`, `J` e o número de episódios como **alvos revisáveis após piloto**, com critério de suficiência: convergência da curva, estabilidade entre sementes e largura do intervalo do efeito principal.
- [ ] Definir o que será transferido para 1:1: parâmetros da política, arquitetura, metamodelo ou apenas hipóteses. Especificar testes de diferença entre escalas nos indicadores e na ordenação das políticas. “Reproduzir todos os procedimentos” pode ser inviável e ainda não é um plano operacional.
- [ ] Adicionar marcos no cronograma para: especificação de recompensa e baselines, validação do metamodelo, piloto de RL, teste fora da amostra e confirmação na escala 1:1. O cronograma atual não tem atividade própria de construção/validação do metamodelo e inclui “avaliar o paper do aprendizado de máquina supervisionado”, que não identifica uma entrega.
- [ ] Prever um resultado mínimo viável caso o RL na escala integral custe demais: política fixa otimizada, metamodelo validado e avaliação da política treinada na escala reduzida em um conjunto limitado de simulações 1:1, com a limitação declarada.

### 8. Documentar melhor os resultados parciais e alinhar o protótipo

**Onde:** resultados parciais (334–352) e protótipo em [`government-rl`](../machine-learning/government-rl/).

- [ ] Para cada figura, informar número de configurações, sementes, indicadores, definição de erro, separação dos dados e conclusão limitada que ela sustenta. A curva de aprendizagem e uma trajetória escolhida não demonstram que o metamodelo generaliza para novas políticas nem que uma política adaptativa supera baselines.
- [ ] Explicitar que o protótipo atual é **exploratório**: ele usa três alavancas (renda, benefício, gasto), enquanto o plano prevê quatro (incluindo IVA); a recompensa implementada usa consumo das famílias e penalidade terminal de dívida, enquanto a equação do plano usa PIB e penalidades periódicas de déficit/dívida. Definir se o experimento final alinhará código e plano ou se as mudanças serão justificadas no texto.
- [ ] Aproveitar o que já existe no protótipo: há comparações com políticas fixas e conjuntos distintos de sementes em `run_experiment.jl`. Descrever o desenho final no plano, com a função de recompensa e as quatro alavancas decididas.

## Prioridade 3 — precisão editorial

- [ ] Corrigir duplicação “referências fiscais referências fiscais” e “défict” na pergunta central (56); corrigir a terceira pergunta secundária (62).
- [ ] Remover a citação repetida de Zheng et al. e separar LLMs de aprendizagem por reforço na revisão (101).
- [ ] Uniformizar `BeforeIT.jl`, “aprendizagem por reforço”, “déficit”, “dívida” e termos de política fiscal. Revisar erros de digitação na introdução, método e cronograma.
- [ ] Verificar a data do documento (`Outrubro`) e revisar se as referências bibliográficas sustentam precisamente cada afirmação.
- [ ] Chamar 3% e 60% de **referências inspiradas em regras europeias**, com a referência histórica correta, evitando apresentá-las como garantia automática de conformidade ou como contribuição de Brusatin et al.

## Ordem recomendada de revisão

1. **Pergunta, hipóteses e medidas finais.** Decidir o que conta como melhora e o que conta como desvio fiscal aceitável.
2. **Especificação do agente.** Observações, quatro ações, limites, tempo da decisão, horizonte e algoritmo.
3. **Recompensa e baselines.** Normalizar componentes, justificar pesos e fixar a política fixa otimizada como comparação principal.
4. **Metamodelo.** Mantê-lo como ferramenta para políticas fixas e retirar a ligação artificial com `Δφ`, salvo se for proposta uma modelagem dinâmica adicional.
5. **Protocolo de avaliação e viabilidade.** Sementes independentes, choques, métricas, incerteza, orçamento de simulações e validação 1:1.
6. **Revisão, justificativa, resultados parciais e cronograma.** Reescrever essas partes depois das decisões metodológicas para que descrevam o mesmo estudo.

## Critério prático para considerar o plano fechado

Um leitor deve conseguir responder, **sem perguntar ao autor**: que informações o governo recebe e quando; quais parâmetros ele pode alterar e em que faixa; qual retorno ele maximiza; o que ocorre se ultrapassar 3% ou 60%; como a melhor política fixa é escolhida; em quais simulações a política é treinada e testada; quais resultados indicam ganho, custo fiscal e instabilidade; qual função exata o metamodelo exerce; e o que será feito na escala 1:1. Esses pontos são mais importantes para fechar a proposta que escolher agora valores finais de todos os pesos ou um número definitivo de episódios.
