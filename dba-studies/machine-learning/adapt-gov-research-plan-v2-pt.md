# AdaptGov: aprendizado de política fiscal adaptativa em um modelo macroeconômico baseado em agentes

## 1. Resumo e enquadramento

Esta pesquisa investiga se uma autoridade fiscal que ajusta suas decisões ao estado da economia consegue melhorar resultados sociais e macroeconômicos em uma pequena economia aberta simulada no **BeforeIT.jl**. O estudo combina simulação baseada em agentes, análise de sensibilidade e aprendizado por reforço (AR), com um modelo substituto de trajetórias se o custo computacional exigir. A política aprendida será comparada com a regra fiscal original do simulador, uma política fixa otimizada e uma regra simples de resposta ao ciclo econômico. Toda conclusão sobre desempenho será testada novamente no modelo completo.

O enquadramento proposto é a linha **Ciências Sociais e Ambientais Aplicadas** em Modelagem de Sistemas Complexos: decisões fiscais alteram interações entre famílias, empresas, mercados, governo e setor externo; seus efeitos agregados emergem de respostas heterogêneas, realimentações e choques. O resultado esperado é uma avaliação de políticas *dentro das hipóteses do modelo*, e não a prescrição de uma política ótima para um país real.

## 2. Problema, pergunta e hipóteses

Modelos macroeconômicos baseados em agentes representam decisões descentralizadas e permitem observar resultados distributivos e setoriais além dos agregados ([Dawid e Delli Gatti, 2018](https://doi.org/10.1016/bs.hescom.2018.02.006)). O modelo de [Poledna et al. (2023)](https://doi.org/10.1016/j.euroecorev.2022.104306) articula dados de contas nacionais, setores e matrizes insumo-produto para uma pequena economia aberta. O [BeforeIT.jl](https://arxiv.org/abs/2502.13267) oferece uma implementação aberta e extensível do modelo de base. Isso torna possível experimentar respostas fiscais condicionadas ao estado econômico, desde que as intervenções respeitem a ordem das decisões e as identidades contábeis da simulação.

**Pergunta central:** em cenários simulados e não observados durante o treinamento, uma política fiscal adaptativa melhora uma medida de bem-estar previamente definida em relação a políticas fixas e regras simples de resposta, sem deterioração inaceitável da dívida pública, da estabilidade econômica ou dos resultados dos grupos mais vulneráveis?

Perguntas complementares:

1. Quais instrumentos fiscais produzem efeitos identificáveis acima do ruído estocástico do modelo?
2. Um substituto de trajetórias prevê suficientemente bem as consequências de *intervenções sequenciais* para apoiar o treinamento de uma política?
3. Em quais estados da economia a política aprendida age de modo diferente dos comparadores, e essas diferenças resistem a choques e mudanças plausíveis de calibração?

Hipóteses de trabalho: **H1**, ao menos um instrumento fiscal admissível tem efeito mensurável sobre bem-estar e contas públicas; **H2**, uma regra dependente do estado supera os comparadores no mesmo conjunto de cenários de teste e sob orçamento computacional comparável; **H3**, eventual ganho permanece sob choques, sementes e parâmetros não vistos. Cada hipótese pode ser rejeitada sem comprometer o valor da análise de sensibilidade e dos comparadores.

## 3. Objetivos

**Objetivo geral:** desenvolver e avaliar uma política fiscal adaptativa no BeforeIT, com critérios explícitos de bem-estar, viabilidade fiscal e robustez.

| Objetivo específico | Etapa metodológica correspondente |
| --- | --- |
| Mapear os instrumentos, observações, grupos de famílias e identidades fiscais implementados no modelo. | Auditoria do simulador e reprodução da linha de base. |
| Estimar a sensibilidade dos resultados a alterações fiscais viáveis. | Experimentos pareados com repetição de sementes. |
| Construir e validar, se necessário, um substituto para trajetórias sob ações sequenciais. | Geração de dados intervencionais e validação de previsões em múltiplos horizontes. |
| Treinar e interpretar uma política adaptativa. | Aprendizado por reforço com limites de ação e monitoramento de incerteza. |
| Comparar políticas e testar sua robustez no modelo completo. | Avaliação em cenários reservados, choques e calibrações alternativas. |

## 4. Fundamentação e lacuna

A literatura de macroeconomia baseada em agentes fundamenta o estudo de heterogeneidade, emergência e dinâmica não linear ([Dawid e Delli Gatti, 2018](https://doi.org/10.1016/bs.hescom.2018.02.006)). [Dosi et al. (2015)](https://doi.org/10.1016/j.jedc.2014.11.014) analisam políticas fiscais anticíclicas e sua interação com políticas monetárias em outra economia simulada, oferecendo padrões qualitativos para confronto. [Poledna et al. (2023)](https://doi.org/10.1016/j.euroecorev.2022.104306) demonstram o uso de um modelo calibrado para previsão e análise de cenários; [Glielmo et al. (2025)](https://arxiv.org/abs/2502.13267) apresentam o BeforeIT como plataforma computacional para sua extensão. O [AI Economist](https://doi.org/10.1126/sciadv.abk2607) demonstra o uso de AR para desenhar políticas tributárias em economias simuladas, com uma organização de agentes diferente.

A lacuna específica deste projeto é verificar **se a adaptação fiscal acrescenta valor** em um modelo macroeconômico calibrado, com regras comportamentais existentes para empresas e famílias, e se esse valor persiste quando a política é executada no próprio simulador. O estudo também examina o risco metodológico de uma política explorar erros de um modelo substituto. Não se pressupõe que a maior complexidade de AR seja necessária: uma regra simples pode vencer ou empatar.

## 5. Metodologia

### 5.1. Desenho, dados e unidade experimental

O estudo é computacional e contrafactual. Cada episódio corresponde a uma simulação do BeforeIT com decisões fiscais trimestrais, inicialmente por **12 trimestres**. As entradas são a calibração e as condições iniciais disponíveis, parâmetros fiscais admissíveis, sementes aleatórias e trajetórias de choques externos. As saídas incluem atividade, consumo por grupo, emprego, preços, arrecadação, despesa, déficit e dívida. Séries empíricas usadas na calibração ou em verificações externas serão identificadas separadamente dos dados gerados por simulação.

Antes de treinar qualquer política, serão fixadas as versões do código e da calibração, reproduzida a trajetória de referência e testada a equivalência de uma intervenção neutra à execução original com a mesma semente. Serão documentadas unidades, deflatores, frequência temporal, cobertura dos grupos e identidade do orçamento público. Não há coleta de dados pessoais ou intervenção sobre participantes humanos prevista neste desenho.

### 5.2. Problema de decisão fiscal

No início do trimestre $t$, o governo observa apenas informações disponíveis até o **fim de $t-1$**. O vetor de observação candidato contém crescimento real do PIB, desemprego, inflação, receita, consumo público, dívida/PIB, consumo real por grupo familiar, instrumentos fiscais vigentes e indicadores externos disponíveis. Sua composição final dependerá da auditoria das séries e de um teste para impedir vazamento de informação do trimestre corrente.

O piloto terá três instrumentos: mudança limitada da alíquota do imposto de renda (`tau_INC`), mudança limitada da taxa de reposição do seguro-desemprego (`theta_UB`) e um multiplicador limitado da **demanda** de consumo do governo. Os limites de nível e de variação trimestral serão definidos antes da otimização, com base na calibração, na viabilidade institucional simulada e na análise de sensibilidade. O imposto sobre valor agregado (`tau_VAT`) e as transferências (`sb_other` e `sb_inact`, esta última destinada aos inativos) são extensões condicionais, caso haja evidência de efeitos identificáveis e uma regra de atualização contábil clara. A taxa de juros permanece sob a regra do banco central do modelo.

A ação aplicada é $a_t=(\tau_{t}^{INC},\theta_{t}^{UB},\log m_t^G)$, em que $m_t^G=1$ reproduz a demanda pública da regra original. O agente propõe alterações limitadas nas duas taxas e escolhe o multiplicador do trimestre; o vetor registra os níveis efetivamente aplicados.

O consumo público requer intervenção no momento correto da execução. No código atual, `gov_expenditure` sorteia o consumo `C_G` por uma regra autorregressiva e calcula a demanda local `C_d_j`; atribuir `C_G` antes desse cálculo seria sobrescrito. O controle proposto multiplica **ambos** os valores produzidos pela regra no trimestre, preservando a relação entre eles e a propagação autorregressiva ao trimestre seguinte. A despesa planejada e a efetivamente realizada serão medidas separadamente, pois as compras dependem do mercado de bens. As transferências também exigem atenção: seu valor é atualizado por crescimento esperado em cada passo do modelo.

### 5.3. Bem-estar, restrições e comparadores

A função de avaliação será declarada antes do treinamento. Uma especificação inicial é

$$
J(\mu)=\mathbb{E}\left[\sum_{t=1}^{T}\delta^{t-1}\left(
\sum_{g\in\mathcal G}w_g\frac{1}{N_g}\sum_{h\in g}
\log\frac{c^{\mathrm{real}}_{h,t}+\varepsilon}{c_{\mathrm{ref}}}
-\lambda_u u_t-\lambda_\pi|\pi_t-\pi^*|
-\lambda_a\left\|\frac{a_t-a_{t-1}}{s}\right\|_2^2
\right)-\lambda_D\frac{D_T-D_0}{Y_0^{\mathrm{anual}}}\right].
$$

Aqui, $\mu$ é a regra fiscal, $T$ o horizonte, $\delta$ o fator de desconto, $N_g$ o número de famílias do grupo e $\varepsilon$ um deslocamento fixo para consumo nulo. Além disso, $g$ representa grupos familiares, $c^{\mathrm{real}}_{h,t}$ é o consumo realizado e deflacionado, $u_t$ é o desemprego, $\pi_t$ a inflação, $D_t$ a dívida e $s$ as escalas de alteração dos instrumentos. Os pesos $w_g$, as penalidades $\lambda$, o alvo de inflação e o consumo de referência são **escolhas normativas**, explicitadas e submetidas a análise de sensibilidade. A escala anual do PIB no denominador da dívida será calculada de modo consistente com a frequência trimestral. Consumo zero, grupos sem observações e proprietários de empresas e do banco exigem regras de cobertura documentadas. Se o consumo individual não sustentar uma medida confiável de bem-estar, será usada uma aproximação rotulada como tal, com conclusão mais estreita.

Serão aplicados limites duros aos instrumentos; dívida, déficit, distribuição do consumo, emprego, PIB, inflação e consumo público realizado serão reportados mesmo quando não entrarem diretamente na função de recompensa. Não se adotará automaticamente um teto de dívida de 60% do PIB: um limite, se usado, precisará ser justificado para a calibração escolhida. Também não se atribuirá benefício social direto ao consumo público sem uma medida da qualidade dos serviços prestados.

Os comparadores são: (1) regra fiscal original; (2) melhor combinação fixa admissível encontrada no orçamento de busca declarado; e (3) regra simples de resposta ao desemprego, ao crescimento e à dívida. Seus ajustes usarão apenas cenários de treinamento, com custo de simulação registrado e comparável ao da política aprendida.

### 5.4. Sequência experimental e critérios de passagem

1. **Interface e sensibilidade.** Auditar a execução fiscal, verificar a intervenção neutra e as identidades contábeis; então comparar perturbações fiscais com a linha de base usando as mesmas sementes. Medir efeitos, variância entre repetições e custo por episódio. **Prosseguir** se houver efeitos interpretáveis acima de um limiar mínimo declarado e sem incoerência contábil.
2. **Comparadores.** Ajustar política fixa e regra simples sob o mesmo domínio de ações. **Prosseguir** para AR se os comparadores forem reproduzíveis e houver variação de estados que possa justificar adaptação.
3. **Substituto de trajetórias, se o custo exigir.** Gerar simulações com *sequências* de ações fiscais viáveis, choques e sementes; reservar cenários completos para validação e teste. Ajustar primeiro um preditor simples de transição e comparar com alternativas recorrentes, como GRU, apenas se necessário. Um Transformer temporal é possibilidade posterior, dependente de dados e ganho demonstrado. O modelo deverá prever trajetórias de 1 a 12 trimestres, distribuição ou intervalos de incerteza e variáveis fiscais relevantes. Serão avaliados erro por horizonte, cobertura dos intervalos, conservação de relações contábeis, desempenho nas bordas do domínio e capacidade de **ordenar políticas**. O substituto já planejado em [`surrogate/surrogate-generation-plan.md`](surrogate/surrogate-generation-plan.md) prevê resultados médios de configurações fixas; ele não satisfaz sozinho esses critérios de transição sob decisões sequenciais. **Prosseguir** somente se a validação intervencional passar por limites declarados antes do ajuste.
4. **Aprendizado da política.** Começar com ações discretas e uma política compacta, ou usar treinamento direto no simulador caso o custo medido o permita. PPO ou SAC serão considerados se a dimensão contínua das ações e a comparação experimental justificarem o uso. No substituto, penalizar ou bloquear estados e ações fora da região coberta pelos dados; um conjunto de modelos pode estimar desacordo e ajudar a detectar extrapolação. Registrar sementes, recompensas por componente, ações propostas e aplicadas, falhas e tempo computacional. Reexecutar políticas selecionadas no BeforeIT completo.
5. **Avaliação final.** Congelar políticas, pesos, limites e métricas antes de abrir o teste. Separar por cenário completo, e não por trimestre; usar sementes, sequências de choques e condições iniciais reservadas. Comparar políticas em cenários pareados, com intervalos de incerteza, perdas de cauda, dívida, consumo por grupo e trajetória temporal. Verificar choques externos, horizonte mais longo e perturbações plausíveis da calibração. Um ganho só será considerado sustentado se superar os comparadores por uma diferença mínima previamente declarada, sem piora fiscal ou distributiva além dos limites definidos.

O tamanho da amostra e o número de sementes serão dimensionados após medir ruído e custo. Valores como mil configurações, dez sementes, cinco redes ou quinhentas reexecuções podem servir como **cenários de orçamento**, mas não são requisitos nem evidência de suficiência estatística. O projeto pode concluir de forma válida que uma política simples é preferível ou que o substituto ainda não é confiável.

### 5.5. Reprodutibilidade e interpretação

Cada experimento registrará versão do código, calibração, domínio dos instrumentos, cenário, semente, trajetória completa, falhas e tempo de execução. Resultados serão apresentados por componente do bem-estar e por grupo, além de gráficos que relacionem estados observados às decisões fiscais. Os sinais e padrões das respostas fiscais serão confrontados com a literatura de modelos baseados em agentes, incluindo Dosi et al. (2015), sem pressupor equivalência entre modelos. A validação empírica disponível servirá para discutir plausibilidade e limitações; diferenças entre o modelo e a economia observada serão explicitadas. Nenhum resultado do simulador, isoladamente, será interpretado como efeito causal comprovado no mundo real.

## 6. Cronograma de 24 meses

| Atividade e entrega | Sem. 1 | Sem. 2 | Sem. 3 | Sem. 4 |
| --- | :---: | :---: | :---: | :---: |
| Disciplinas, revisão bibliográfica e delimitação da pergunta | X | X |  |  |
| Auditoria do modelo, linha de base, métricas e ética dos dados | X |  |  |  |
| Sensibilidade fiscal e comparação de regras simples | X | X |  |  |
| Projeto e validação inicial do substituto intervencional, se necessário |  | X | X |  |
| Exame de qualificação e incorporação das recomendações |  | X | X |  |
| Treinamento e interpretação da política adaptativa |  |  | X |  |
| Testes reservados, robustez e comparação no simulador completo |  |  | X | X |
| Redação, revisão e depósito da dissertação |  | X | X | X |

A qualificação é planejada para até o **14º mês**; a data deverá ser conferida no regulamento vigente do programa. O desenho mantém uma rota de conclusão caso o substituto ou o AR não passe nos critérios de validação: o estudo de sensibilidade e a comparação entre regras fiscais ainda responderão parte substantiva da pergunta.

## 7. Resultados esperados e limites

Os produtos previstos são: um mapa verificável das intervenções fiscais no BeforeIT; estimativas de sensibilidade com incerteza; comparadores fortes; um substituto de trajetórias validado **se** necessário e viável; uma política adaptativa interpretável; e uma comparação final de bem-estar, distribuição e sustentabilidade fiscal. O principal limite é a dependência das regras comportamentais, da calibração e das variáveis de bem-estar efetivamente representadas. A pesquisa permitirá identificar condições sob as quais a adaptação ajuda, falha ou apenas acrescenta complexidade no ambiente simulado.

## Referências

DAWID, Herbert; DELLI GATTI, Domenico. [Agent-Based Macroeconomics](https://doi.org/10.1016/bs.hescom.2018.02.006). In: *Handbook of Computational Economics*. v. 4, p. 63–156, 2018. DOI: 10.1016/bs.hescom.2018.02.006.

DOSI, Giovanni; FAGIOLO, Giorgio; NAPOLETANO, Mauro; ROVENTINI, Andrea; TREIBICH, Tania. [Fiscal and monetary policies in complex evolving economies](https://doi.org/10.1016/j.jedc.2014.11.014). *Journal of Economic Dynamics and Control*, v. 52, p. 166–189, 2015. DOI: 10.1016/j.jedc.2014.11.014.

GLIELMO, Aldo; DEVETAK, Mitja; MELIGRANA, Adriano; POLEDNA, Sebastian. [BeforeIT.jl: High-Performance Agent-Based Macroeconomics Made Easy](https://arxiv.org/abs/2502.13267). *arXiv*, arXiv:2502.13267, 2025. DOI: 10.48550/arXiv.2502.13267. Preprint.

POLEDNA, Sebastian; MIESS, Michael Gregor; HOMMES, Cars; RABITSCH, Katrin. [Economic forecasting with an agent-based model](https://doi.org/10.1016/j.euroecorev.2022.104306). *European Economic Review*, v. 151, art. 104306, 2023. DOI: 10.1016/j.euroecorev.2022.104306.

ZHENG, Stephan; TROTT, Alexander; SRINIVASA, Sunil; PARKES, David C.; SOCHER, Richard. [The AI Economist: Taxation policy design via two-level deep multiagent reinforcement learning](https://doi.org/10.1126/sciadv.abk2607). *Science Advances*, v. 8, n. 18, eabk2607, 2022. DOI: 10.1126/sciadv.abk2607.
