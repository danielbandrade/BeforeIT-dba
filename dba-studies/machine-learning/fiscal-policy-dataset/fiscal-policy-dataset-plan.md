# Plano curto: dataset de políticas fiscais fixas no BeforeIT

- **Objetivo:** treinar um *surrogate* para prever trajetórias macroeconômicas sob uma política fiscal escolhida no início de cada run e mantida por 12 trimestres.
- **Política:** $p_i=(\tau_i^{INC},\tau_i^{VAT},\theta_i^{UB},m_i^G)\in\mathcal P$, no domínio exploratório definido abaixo.
- **Dinâmica:** para configuração $i$, semente $j$ e trimestre $t$,

  $$
  p_{i,t}=p_i\quad(0\leq t<T),\qquad
  x_{i,j,t+1}=F(x_{i,j,t},p_i,z_{i,j,t},\varepsilon_{i,j,t+1}),\qquad
  s_{i,j,t}=H(x_{i,j,t}).
  $$

  O **estado econômico** $x$ evolui; os **parâmetros da política** não mudam dentro do run.

## Variáveis do dataset

**Entradas fiscais — definidas no início e fixas por run:**

- $\tau^{INC}$ (`tau_INC`): alíquota do imposto de renda.
- $\tau^{VAT}$ (`tau_VAT`): alíquota do imposto sobre valor agregado (IVA).
- $\theta^{UB}$ (`theta_UB`): taxa do seguro-desemprego, expressa como fração do salário de referência.
- $m^G$ (`spending_multiplier`): multiplicador da demanda de consumo do governo, amostrado diretamente. Quando $m^G=0$, o consumo público planejado e realizado é zero; para $m^G>0$, a regra estocástica continua ativa.

**Intervalos exploratórios do piloto e da expansão — 0% a 200% da calibração austríaca carregada:**

- $\tau^{INC}\in[0,2\tau^{INC}_0]$; na referência embutida, **0 a 0,426814** (0% a 42,68%).
- $\tau^{VAT}\in[0,2\tau^{VAT}_0]$; na referência embutida, **0 a 0,305736** (0% a 30,57%).
- $\theta^{UB}\in[0,2\theta^{UB}_0]$; na referência embutida, **0 a 0,717164** (0% a 71,72%).
- $m^G\in[0,2]$, com valor de referência 1. Zero é uma política válida e é amostrado diretamente, sem transformação logarítmica.
- Os limites são contínuos, **não passos de uma grade**. Cada variável é zerada exatamente em sua fronteira inferior; a política com as quatro variáveis zeradas não é uma âncora obrigatória do LHS.

**Saídas — observadas a cada trimestre:**

- **PIB real:** `real_gdp`.
- **Consumo real das famílias:** `real_household_consumption`.
- **Formação real de capital:** `real_capitalformation`.
- **Taxa de desemprego:** proporção de trabalhadores ativos sem ocupação, calculada a partir de `model.w_act.O_h`.
- **Inflação trimestral:** variação do deflator `nominal_gdp / real_gdp`.
- **Receita do governo:** `model.gov.Y_G`.
- **Dívida pública:** `model.gov.L_G`.
- **Dívida/PIB:** dívida dividida pelo PIB nominal anualizado.
- **Consumo público planejado:** `model.gov.C_G`.
- **Consumo público realizado:** `model.gov.C_j`.

## Geração

- **Amostragem:** compor $N=100$ vetores: 1 política atual, 8 fronteiras (limite inferior e superior de cada variável, com as demais no valor base) e 91 pontos LHS. Em cada variável, dividir seu intervalo em 91 faixas, sortear um valor por faixa e embaralhar independentemente a associação entre variáveis. Fixar calibração, protocolo de inicialização e horizonte $T=12$. O LHS cobre todo o novo domínio; as fronteiras garantem os quatro zeros individuais.
- **Repetições:** executar cada vetor com um painel comum inicial de $M=5$ sementes. Medir a variância entre sementes antes de ampliar $M$ ou $N$.
- **Registro:** salvar $(configuração_i, semente_j, t, p_i, s_{i,j,t})$, a trajetória completa, falhas, calibração e versão do código.
- **Alvo:** para cada configuração e trimestre, calcular $\bar s_{i,t}=M^{-1}\sum_{j=1}^{M}s_{i,j,t}$ e seu erro padrão. Ajustar $\hat f_\phi(p_i)\approx\mathbb E[(s_1,\ldots,s_T)\mid p_i]$ sob a calibração fixa; preservar as trajetórias por semente para medir incerteza.
- **Validação:** separar treino, validação e teste por **configuração fiscal**, mantendo todas as sementes de uma configuração no mesmo conjunto. Conferir previsões em configurações e sementes novas com runs do BeforeIT.

## Pseudocódigo

```text
fixar calibração, indicadores, horizonte e domínio fiscal exploratório
compor N vetores p[i] com LHS, política atual e fronteiras
para cada configuração i e semente j do painel comum:
    iniciar BeforeIT da mesma calibração de referência com a semente j
    aplicar p[i] antes do primeiro trimestre
    para t = 0,...,T-1:
        manter p[i]; avançar um trimestre; registrar s[t+1]
    salvar configuração, semente, trajetória e eventual falha
agregar trajetórias por configuração; separar treino/validação/teste por i
```

- **Implementação:** `generate_dataset.jl` reutiliza `../government-rl/government_policy.jl` e fixa $\tau^{INC}$, $\tau^{VAT}$, $\theta^{UB}$ e $m^G$ após construir o modelo e antes do primeiro trimestre. Nenhuma decisão depende do estado observado durante o run. A inicialização permanece na calibração austríaca; a política é uma intervenção a partir do trimestre 1.
- **Custo estimado:** um run austríaco em escala 1 levou 569 s para 12 trimestres; $100\times5$ runs seriam aproximadamente 79 horas de simulação serial, sem calibração e gravação. Essa extrapolação usa apenas uma medição.

## Expansão do piloto

- `experiment-expanded.toml` mantém a calibração austríaca, escala `0.001`, horizonte de 12 trimestres e **o mesmo domínio de 0% a 200% do piloto**, mas usa **500 configurações e 10 sementes**: 5.000 runs. O piloto de 100 × 5 fica em outra pasta.
- A nova amostra é independente: política base, oito fronteiras e 491 pontos LHS. As partições são **400 treino, 50 validação e 50 teste**, sempre por configuração. O teste novo avalia o mesmo domínio com amostragem mais densa.
- Comparar os modelos por erro absoluto e NRMSE, lembrando que o NRMSE usa o desvio padrão do treino de cada experimento. Conferir separadamente os resultados nas fronteiras com zero.
- Os experimentos anteriores, com intervalos estreitos, permanecem arquivados nas pastas originais e não são misturados aos novos dados.
