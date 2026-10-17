# Plano curto: dataset de políticas fiscais fixas no BeforeIT

- **Objetivo:** treinar um *surrogate* para prever trajetórias macroeconômicas sob uma política fiscal escolhida no início de cada run e mantida por 12 trimestres.
- **Política:** $p_i=(\tau_i^{INC},\tau_i^{VAT},\theta_i^{UB},\log m_i^G)\in\mathcal P$, no domínio exploratório definido abaixo.
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
- $\theta^{UB}$ (`theta_UB`): taxa de reposição do benefício de desemprego.
- $m^G$ (`spending_multiplier`): multiplicador da demanda de consumo do governo, amostrado como $\log m^G$. A regra estocástica continua ativa, portanto o gasto realizado pode variar mesmo com $m^G$ fixo.

**Intervalos exploratórios do piloto — centrados na calibração austríaca carregada:**

- $\tau^{INC}\in[\tau^{INC}_0-0{,}02,\tau^{INC}_0+0{,}02]$; com a referência austríaca embutida, **0,193407 a 0,233407** (19,34% a 23,34%).
- $\tau^{VAT}\in[\tau^{VAT}_0-0{,}02,\tau^{VAT}_0+0{,}02]$; na referência embutida, **0,132868 a 0,172868** (13,29% a 17,29%).
- $\theta^{UB}\in[\theta^{UB}_0-0{,}05,\theta^{UB}_0+0{,}05]$; na referência embutida, **0,308582 a 0,408582** (30,86% a 40,86%).
- $m^G\in[0{,}95,1{,}05]$, amostrado em $\log m^G\in[\log(0{,}95),\log(1{,}05)]\approx[-0{,}051293,0{,}048790]$.
- Os desvios **0,02** e **0,05** são distâncias até os limites em pontos percentuais, **não passos de uma grade**. São escolhas para o piloto e precisam de avaliação econômica e de estabilidade antes do dataset completo.

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

- **Amostragem:** compor $N=100$ vetores: 1 política atual, 8 fronteiras (limite inferior e superior de cada variável, com as demais no valor base) e 91 pontos LHS. Em cada variável, dividir seu intervalo em 91 faixas, sortear um valor por faixa e embaralhar independentemente a associação entre variáveis. Fixar calibração, protocolo de inicialização e horizonte $T=12$.
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

- **Implementação:** `generate_dataset.jl` reutiliza `../government-rl/government_policy.jl` e fixa $\tau^{INC}$, $\tau^{VAT}$, $\theta^{UB}$ e $m^G$ antes do primeiro trimestre. Nenhuma decisão depende do estado observado durante o run.
- **Custo estimado:** um run austríaco em escala 1 levou 569 s para 12 trimestres; $100\times5$ runs seriam aproximadamente 79 horas de simulação serial, sem calibração e gravação. Essa extrapolação usa apenas uma medição.

## Expansão do piloto

- `experiment-expanded.toml` mantém a calibração austríaca, escala `0.001` e 12 trimestres, mas usa **500 configurações e 10 sementes**: 5.000 runs. O piloto de 100 × 5 continua em sua própria pasta.
- Os novos intervalos são $\tau^{INC}_0\pm0{,}03$, $\tau^{VAT}_0\pm0{,}03$, $\theta^{UB}_0\pm0{,}075$ e $m^G\in[0{,}925,1{,}075]$. Cada largura cresce cerca de 50%; o volume de quatro dimensões cresce cerca de $1{,}5^4\approx5{,}1$ vezes. As 500 configurações mantêm aproximadamente a densidade média do piloto, sem garantir cobertura idêntica perto da referência.
- A nova amostra é independente: política base, oito fronteiras e 491 pontos LHS. As partições são **400 treino, 50 validação e 50 teste**, sempre por configuração. O teste novo é a avaliação final para o domínio ampliado.
- O desenho gerado tem **105 políticas dentro dos limites antigos** (83 treino, 14 validação e 8 teste). O erro de teste nessa região terá incerteza alta por conter só oito políticas.
- Comparar os modelos também por erro absoluto e separar resultados dentro e fora dos limites antigos. O NRMSE calculado com o desvio padrão do novo treino não é diretamente comparável ao NRMSE do piloto, porque o domínio mudou.
