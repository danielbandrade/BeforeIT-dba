# Plano: surrogate das trajetórias de política fiscal

- **Objetivo:** prever a trajetória macroeconômica **média** de 12 trimestres para uma política fiscal fixa $p=(\tau^{INC},\tau^{VAT},\theta^{UB},\log m^G)$, sob a calibração austríaca embutida e escala `0.001`.
- **Unidade estatística:** uma **configuração fiscal**. As cinco sementes medem a variabilidade do BeforeIT; os 500 runs correspondem a 100 valores distintos de $p$.
- **Alvo:** para os dez indicadores do plano do dataset, $y_i=\operatorname{vec}(\bar s_{i,1:12})\in\mathbb R^{120}$, onde $\bar s_{i,t}=M_i^{-1}\sum_j s_{i,j,t}$. O modelo aproxima $f(p)=\mathbb E[y\mid p]$.
- **Arquivos:** juntar `configurations.csv` (entradas e partições) a `summary.csv` (médias por trimestre); usar `observations.csv` para estimar a variação entre sementes.
- **Dados já obtidos em 17/10/2026:** o experimento `experiments/austria-scale-0.001` contém 100 configurações, 500 runs com status `success`, 6.000 observações trimestrais e 1.200 linhas no resumo. Cada configuração já tem cinco runs completos de 12 trimestres; a checagem de integridade necessária para iniciar o treino está satisfeita.
- **Sinal versus ruído:** no trimestre 12 e **apenas nas 80 configurações de treino**, o desvio padrão das médias entre políticas dividido pela mediana do erro padrão entre sementes é aproximadamente 6,5 para PIB real, 1,1 para inflação e 1,3 para dívida/PIB. **Inferência:** inflação e dívida/PIB podem exigir mais sementes ou um alvo mais agregado para distinguir efeitos fiscais pequenos.

## Aplicação ao experimento ampliado

- `experiment-expanded.toml` define 500 políticas, 10 sementes e faixas fiscais cerca de 50% mais largas, em uma nova pasta. O mesmo pipeline usa as partições **400/50/50** por configuração, lidas dos CSVs. As regras abaixo que citam 100 políticas ou 5 sementes descrevem o piloto; no conjunto ampliado, usar os novos tamanhos e recalcular todas as escalas e estimativas de ruído.
- Avaliar separadamente as políticas dentro do domínio antigo e no anel acrescentado. Comparar também MAE/RMSE em unidades originais, pois o NRMSE muda de denominador quando a dispersão de políticas aumenta.

## Modelo recomendado

- **Primeiro ajuste:** regressão Ridge linear e quadrática, com $\Phi(p)=[1,\tilde p_1,\ldots,\tilde p_4,\tilde p_a\tilde p_b\ (a\leq b)]$ (15 termos na versão quadrática). Ajustar um conjunto de coeficientes para os 120 alvos padronizados. Isso fornece uma referência rápida e interpretável.
- **Candidato principal:** componentes principais das trajetórias padronizadas (*PCA*) + processo gaussiano (*GP*) com kernel Matérn e comprimento de escala por entrada. Ajustar a PCA **só no treino**, escolher o número de componentes por erro de validação e prever seus escores com GPs. Essa é uma adaptação de métodos de emulação de saídas de alta dimensão; não há garantia de que superará Ridge neste dataset.

$$
z_i=U_r^\top D^{-1}(y_i-\mu),\qquad
z_{i,q}=g_q(p_i)+\epsilon_{i,q},\quad g_q\sim\mathrm{GP}(0,k_q^{\text{Matérn}}),\qquad
\hat y(p)=\mu+D U_r\hat z(p).
$$

- $\mu$, $D$ e $U_r$ vêm apenas das configurações de treino. Estimar a variância de $\epsilon_{i,q}$ projetando as trajetórias **por semente** na mesma base e dividindo a variância entre sementes por $M_i$; aplicar um piso de ruído para evitar variâncias nulas. A incerteza do GP precisa ser calibrada com dados reservados.
- Escolher componentes pela qualidade de previsão **de cada indicador**, além do erro conjunto: a PCA pode comprimir bem a trajetória total e ainda perder um indicador fiscal importante. Nesse caso, ajustar esse indicador com um GP separado ou ampliar as sementes.
- **Escolha final:** manter Ridge se o GP não reduzir de forma consistente o erro de validação nos indicadores e trimestres relevantes. Nenhuma arquitetura é declarada vencedora antes desse teste.

## Tradeoffs

| Modelo | Vantagem neste dataset | Limitação |
| --- | --- | --- |
| Ridge linear/quadrática | Simples, rápida, interpretável; a versão quadrática representa curvatura e interações básicas com 80 políticas de treino. | Pode suavizar limiares e dinâmicas complexas; intervalos de previsão exigem calibração separada. |
| GP independente por indicador e trimestre | Não exige compressão das saídas; fornece média e desvio preditivo por alvo. | Até 120 ajustes separados; ignora correlação entre trimestres e pode produzir trajetórias pouco coerentes. |
| **PCA + GP** | Compartilha padrões entre indicadores e trimestres; reduz o número de GPs e permite modelar resposta não linear em quatro entradas. | PCA pode descartar efeitos pequenos porém importantes; requer padronização, escolha de componentes e validação da incerteza reconstruída. |
| MLP pequeno sobre escores PCA | Pode aprender relações não lineares e compartilhar padrões das saídas. | Com 80 políticas de treino, precisa de forte regularização, várias inicializações e validação rigorosa; incerteza preditiva exige trabalho adicional. |
| Rede recorrente ou Transformer | Pode ser útil para políticas que mudem a cada trimestre e usem o estado observado. | A política deste dataset é fixa; a arquitetura temporal adiciona parâmetros sem evidência de ganho. |

## Como avaliar se 100 políticas bastam

- **Não há um limiar universal:** são 80 políticas no treino, não 400 exemplos independentes adicionais vindos das sementes. A Ridge quadrática tem 15 termos por alvo, mas essa razão sozinha não mede generalização.
- **Curva de aprendizado:** dentro das 80 políticas de treino, repetir divisões por configuração com 10 políticas de avaliação interna. Em cada divisão, ajustar o mesmo pipeline com 20, 40, 60 e 70 das outras políticas; medir MAE/RMSE nas 10 reservadas. Reajustar padronização e PCA a cada subconjunto. Preservar as 10 políticas de validação e as 10 de teste externas.
- **Interpretar a curva:** erro de avaliação ainda caindo em 70 políticas sugere benefício de **novas configurações**; erro estabilizado perto da incerteza entre sementes sugere amostra suficiente para aquele alvo; erro estabilizado muito acima dela sugere rever modelo, indicadores ou domínio antes de apenas aumentar $N$.
- **Separar duas necessidades:** quando o erro padrão da média é grande frente ao efeito entre políticas, acrescentar **sementes por configuração**; quando a resposta varia com a política mas o erro fora da amostra continua alto, acrescentar **configurações fiscais** nas regiões mal previstas. Usar diferenças emparelhadas entre políticas sob as sementes comuns para verificar efeitos pequenos.
- As 10 configurações de teste dão uma estimativa final pouco precisa; após escolher o modelo, confirmar em novas políticas interiores e de fronteira, com sementes novas. Nunca ajustar hiperparâmetros usando esse teste.

## Treino e decisão

- Manter as partições já gravadas em `configurations.csv`: 80 políticas para treino, 10 para validação e 10 para teste. Todas as sementes e todos os trimestres de uma política ficam na mesma partição. Ajustar escalas, PCA e hiperparâmetros sem consultar o teste.
- Selecionar complexidade por validação e, se necessário, validação cruzada **por configuração** dentro do conjunto de treino. Comparar preditor da média, Ridge linear, Ridge quadrática e PCA + GP nessa ordem.
- Se esses modelos deixarem padrões de erro relevantes, testar uma MLP pequena sobre os mesmos escores PCA, com regularização e várias inicializações. Adotá-la apenas se melhorar a previsão fora da amostra de modo consistente.
- Medir MAE e RMSE por indicador e trimestre; comparar os erros com a dispersão entre sementes e verificar viés nas fronteiras fiscais. Conferir coerência temporal, limites físicos e cobertura dos intervalos. Definir tolerâncias úteis para a decisão econômica **antes** de abrir o teste.
- Depois de escolher o modelo na validação, avaliá-lo uma vez no teste e confirmar com novas configurações e sementes do BeforeIT. Se o objetivo for ordenar políticas, definir primeiro a função de avaliação fiscal e medir também erros de ordenação.
- Guardar modelo, escalas, base PCA, hiperparâmetros, partições, métricas e versão do dataset. Recusar previsões fora dos intervalos fiscais e da calibração/escala treinadas. Um surrogate da escala `0.001` não valida automaticamente previsões na escala `1` nem políticas que mudam durante o run.

## Pseudocódigo

```text
validar runs e juntar política p[i] às médias y[i] por configuração
fixar treino/validação/teste por configuration_id
traçar curvas de aprendizado dentro do treino para decidir se faltam políticas
ajustar escalas somente no treino; comparar Ridge linear e quadrática
ajustar PCA no treino; projetar médias e trajetórias por semente
ajustar GP Matérn para cada escore; selecionar componentes/hiperparâmetros na validação
escolher o modelo com menor erro relevante e intervalos calibrados
avaliar uma vez no teste; validar com novas simulações BeforeIT
salvar artefatos e limites de uso
```

## Referências metodológicas

- [Higdon et al. (2008), *Computer Model Calibration Using High-Dimensional Output*](https://laro.lanl.gov/esploro/outputs/journalArticle/Computer-model-calibration-using-high-dimensional-output/9916363914303761): uso de bases de componentes principais para saídas de simuladores de alta dimensão.
- [scikit-learn: processos gaussianos](https://scikit-learn.org/stable/modules/gaussian_process.html): kernels Matérn, previsão probabilística e ruído por observação.
- [scikit-learn: regressão Ridge](https://scikit-learn.org/stable/modules/linear_model.html#ridge-regression-and-classification): baseline regularizado.
- [scikit-learn: curvas de aprendizado](https://scikit-learn.org/stable/modules/learning_curve.html): diagnóstico de erro conforme cresce o número de exemplos de treino.
- [scikit-learn: GroupKFold](https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.GroupKFold.html): partições sem misturar observações da mesma configuração.
