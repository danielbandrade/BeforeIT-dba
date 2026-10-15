# AdaptGov: searching a optimal fiscal policy in a realistic macroeconomic agent based model

## Introduction

### Problem and Context 

In agent-based macroeconomic models, different types of heterogeneous
agents endowed with behavioral and expectational rules interact through explicitly
represented market protocols and meso- as well as macroeconomic variables are determined by actual aggregation of the output in this population of agents (Dawid and Gatti, 2018). 

The work in *Poledna et al. and Gilemo et al.* establish a realistic and composable agent based model for an small open economy based on national account data. As this model is composed by a rich set of agents found in the real economy, such as active and inactive househouds, consumer and capital firms, a bank, the government, a central bank, and has levaraged national accounts data, such as the input-output matrix, basel III regulations to create a relistic simulation, it can be use as a test bed for diferent economic cenarios, including how changes in government spending and taxation can affect the economy. 

### Research Questions

RQ1: Can a optimal adaptive behaviour for government fiscal policy in a highly non linear realistic macroeconomic agent based model for a small open economy be found?

RQ2: Does the behaviour pattern found in this policy match those found economic agent based literature? 


### Objectives


Main objective:
- Research the creation of a optimal fiscal policy government agent in a realistic macroeconomic model for a small open economy

Secondary objectives:
- Understand and describe the behaviour of the model proposed by *Poledna et. al*
- Run a sensitive analysis of core fiscal policy actions in the simulation
- Review the economic outcome of the simulations using the new government agent though shocks in the economy 
- Compare the emerging policies with the agent based macroeconomic literature 

### Justification

Agent based models consist of a poweful tool for representing and understanding the highly non-linear and complex beahaviour of the economy from a bottom up approach. In this sense, researching the behaviour of governments in such models can be instructive booth for exploring the validity of the model but also for informing how the underling economic phenomenon behaves.  

Additionally, as agent based models can be become increasingly reliable tools for economic modeling and forecasting, searching for optimal government behaviour can be seen as efective planning tool for policy makers. 


## Bibliografy 

Brian Arthur, Dewid and Gatti, Gallegati, Poledna et al, Sutton.

## Methodology 

### Approach 

The main method for this research will be perfoming simulations, using of machine learning tools for the creating a new government agent and statiscal analisys for evaluating the results. 

### Data 

This work will be based mainly on simulation generated data but will also leverage empirical data for qualitative validation of the results. 

### Techniques and tools 

Simulation, machine learning, statistical analysis. 

### Activity schedule

| Activity and method | Expected output | Sem 1 | Sem 2 | Sem 3 | Sem 4 |
|---|---|:---:|:---:|:---:|:---:|
| Review the literature and document the model’s fiscal rules and economic indicators | Research gap and reproducible baseline | ✓ | | | |
| Run sensitivity analyses of selected tax and government spending decisions across repeated simulations | Feasible policy ranges and measurable effects | ✓ | ✓ | | |
| Define the policy objective and compare the existing rule with simple fixed or feedback policies | Evaluation criteria and comparison results | | ✓ | | |
| Assess the role of supervised learning and develop an adaptive government agent using reinforcement learning | Trained policy and documented decisions | | | ✓ | |
| Test all policies on new simulation runs and economic shocks; compare outcomes and uncertainty | Welfare, fiscal, and robustness results | | | ✓ | ✓ |
| Complete coursework, qualification, writing, and submission | Qualification and dissertation | ✓ | ✓ | | ✓ |

## References 

DAWID, Herbert; DELLI GATTI, Domenico. [Agent-Based Macroeconomics](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3112074). *Bielefeld Working Papers in Economics and Management*, n. 02-2018, 2018. DOI: [10.2139/ssrn.3112074](https://doi.org/10.2139/ssrn.3112074).

GLIELMO, Aldo; DEVETAK, Mitja; MELIGRANA, Adriano; POLEDNA, Sebastian. [BeforeIT.jl: High-Performance Agent-Based Macroeconomics Made Easy](https://arxiv.org/abs/2502.13267). *arXiv*, arXiv:2502.13267, 2025. DOI: [10.48550/arXiv.2502.13267](https://doi.org/10.48550/arXiv.2502.13267).

LEONTIEF, Wassily W. [Input-Output Economics](https://www.scientificamerican.com/article/input-output-economics/) (A economia do insumo-produto). *Scientific American*, v. 185, n. 4, p. 15–21, 1951. DOI: [10.1038/scientificamerican1051-15](https://doi.org/10.1038/scientificamerican1051-15).

POLEDNA, Sebastian; MIESS, Michael Gregor; HOMMES, Cars; RABITSCH, Katrin. [Economic forecasting with an agent-based model](https://www.sciencedirect.com/science/article/pii/S0014292122001891). *European Economic Review*, v. 151, art. 104306, 2023. DOI: [10.1016/j.euroecorev.2022.104306](https://doi.org/10.1016/j.euroecorev.2022.104306).



------------------

# Outline  

## 1. Título

O que deve conter:

- Objeto de estudo, abordagem metodológica e, se possível, o recorte (domínio de aplicação, população, sistema).
- Sinalizar a conexão com Modelagem de Sistemas Complexos: linguagem de modelagem quantitativa/computacional, redes, agentes, dinâmica não linear, emergência, etc.
- Enquadrar em uma das duas linhas do programa: "Ciências Sociais e Ambientais Aplicadas" ou "Fundamentos de Sistemas Complexos".

Evite: títulos genéricos, sem método ou sem recorte. Prefira específico e verificável a amplo e vago.

---

## 2. Introdução: objetivos e justificativa

### 2.1. Contextualização do problema

- Apresentar o fenômeno/sistema de interesse e por que ele é um problema relevante.
- Deixar explícito o caráter de sistema complexo: múltiplos agentes/componentes interagindo, comportamento emergente, não linearidade, feedbacks, adaptação.

### 2.2. Pergunta de pesquisa

- Uma pergunta central, clara e respondível dentro de 24 meses.
- Opcional: 2 a 4 subperguntas que a decompõem.

### 2.3. Objetivos

- Objetivo geral: uma frase, alinhada à pergunta central.
- Objetivos específicos: 3 a 5 itens, cada um começando com verbo no infinitivo (mapear, modelar, simular, estimar, validar, comparar). Cada objetivo específico deve ter correspondência direta com uma etapa da metodologia.

### 2.4. Justificativa

- Relevância científica: qual lacuna o trabalho preenche.
- Relevância aplicada/social: por que importa fora da academia (saúde, gestão, política pública, ambiente — os domínios do programa).
- Aderência ao programa: por que este trabalho pertence ao SCX e não a um mestrado de área específica. Este ponto costuma ser cobrado na arguição.

---

## 3. Revisão bibliográfica

O que deve conter:

- Estado da arte do problema e dos métodos, não uma lista solta de resumos.
- Organização temática ou por abordagem, mostrando como os trabalhos dialogam entre si.
- Referências recentes (últimos 5 anos) combinadas com os trabalhos seminais da área.
- Fechamento apontando a lacuna que justifica a pesquisa — a revisão deve "desembocar" na pergunta da seção 2.

Sinais de qualidade que a banca procura:

- Domínio das ferramentas de sistemas complexos aplicáveis ao problema (redes complexas, modelos baseados em agentes, sistemas dinâmicos, autômatos celulares, processos estocásticos, ciência de dados).
- Capacidade de posicionar o próprio trabalho no mapa da literatura.

Evite: citar sem ler, revisão puramente descritiva, ausência de trabalhos metodológicos.

---

## 4. Metodologia e plano de atividades

### 4.1. Abordagem e desenho

- Tipo de estudo (modelagem teórica, simulação, análise de dados empíricos, modelo híbrido).
- Justificar por que o método escolhido responde à pergunta — coerência com objetivos específicos.

### 4.2. Dados

- Fontes (bases públicas, dados primários, dados simulados). Se depende de dado sensível ou de terceiros, indicar disponibilidade e plano B.
- Aspectos éticos, se envolver seres humanos (menção a comitê de ética, se aplicável).

### 4.3. Técnicas e ferramentas

- Métodos quantitativos/computacionais específicos e ferramentas (Python, R, NetLogo, etc.).
- Como cada técnica será validada (métricas, calibração, análise de sensibilidade).

### 4.4. Plano de atividades / cronograma

- Tabela de atividades por semestre, cabendo em 24 meses (com folga para o depósito em até 28 meses).
- Marcos obrigatórios do programa embutidos no cronograma:
  - Cumprimento de créditos em disciplinas.
  - Exame de Qualificação (inscrição até 14 meses após a 1ª matrícula).
  - Redação e depósito da dissertação.

Exemplo de estrutura de cronograma:

| Atividade | Sem 1 | Sem 2 | Sem 3 | Sem 4 |
|---|---|---|---|---|
| Disciplinas / créditos | X | X | | |
| Revisão bibliográfica aprofundada | X | X | | |
| Coleta / preparação de dados | | X | X | |
| Desenvolvimento do modelo | | X | X | |
| Qualificação | | X | | |
| Análise de resultados | | | X | X |
| Redação e depósito | | | X | X |

---

## 5. Resultados parciais (se houver)

O que deve conter, quando aplicável:

- Resultados preliminares, protótipos, análises exploratórias ou publicações já relacionadas ao tema.
- Produções que evidenciem experiência em pesquisa/desenvolvimento — úteis também para reforçar o CV (peso 2 na 1ª fase) e, mais adiante, para pedido de aproveitamento de créditos especiais (até 25 créditos).

Seção opcional. Se não houver resultados, pode ser omitida ou substituída por "Resultados esperados", descrevendo o que se pretende obter e o impacto previsto.

---

## 6. Referências bibliográficas

O que deve conter:

- Todas as obras citadas ao longo do texto, e apenas elas.
- Norma consistente (ABNT ou APA — escolha uma e mantenha).
- Predominância de fontes revisadas por pares; sinalizar quando usar preprints ou fontes técnicas.

---

## Checklist final antes de enviar

- [ ] Título específico, com método e recorte, ligado a uma das linhas do programa
- [ ] Pergunta de pesquisa clara e respondível em 24 meses
- [ ] Objetivos específicos mapeados um a um na metodologia
- [ ] Aderência ao SCX explicitada (por que aqui e não em outro programa)
- [ ] Revisão desemboca na lacuna que justifica o trabalho
- [ ] Metodologia com dados, técnicas e validação definidos
- [ ] Cronograma cabe em 24 meses e inclui Qualificação e depósito
- [ ] Referências completas e em norma única
- [ ] Coerência entre todas as seções (pergunta → objetivos → método → cronograma)
- [ ] Preparado para defender cada escolha na arguição oral (2ª fase, peso 2)