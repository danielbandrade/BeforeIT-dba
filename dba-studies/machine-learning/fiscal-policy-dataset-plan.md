# Plano curto: dataset fiscal para o BeforeIT

- **Objetivo:** gerar dados para medir efeitos de políticas fixas e treinar um *surrogate* capaz de prever decisões fiscais trimestrais.
- **Alavancas:** $p_t=(\tau_t^{INC},\tau_t^{VAT},\theta_t^{UB},\log m_t^G)$: imposto de renda, IVA, benefício de desemprego e multiplicador do consumo público. Definir limites viáveis para o BeforeIT, sem importar automaticamente os valores da Áustria do documento de referência.
- **Transição:** $s_t=H(x_t)$ é a observação disponível antes da decisão; $x_{t+1}=F(x_t,p_t,z_t,\varepsilon_{t+1})$ é o estado após um trimestre, com choque externo $z_t$ e aleatoriedade interna $\varepsilon_{t+1}$.

## Etapa 1 — Política fixa por run

- **Desenho:** amostrar $N_1=100$ combinações fiscais viáveis por LHS, incluindo a política atual e pontos próximos dos limites; em cada run, $p_t=p_i$ para todo $t=0,\ldots,11$.
- **Repetições:** rodar cada $p_i$ com as mesmas $M=5$ sementes iniciais. Estimar, para cada indicador final $y$, $\bar y_i=M^{-1}\sum_{j=1}^{M}y_{ij}$ e $SE_i=sd(y_{ij})/\sqrt M$.
- **Decisão:** comparar efeitos das alavancas com o ruído entre sementes; ajustar $M$ ou o domínio fiscal se os efeitos não forem distinguíveis. Usar esta etapa para estabelecer a sensibilidade e o comportamento de referência.

## Etapa 2 — Política variável por trimestre

- **Desenho:** partir de níveis iniciais viáveis e gerar $N_2=100$ trajetórias com mudanças limitadas em trimestres sorteados, além de controles sem mudança:

  $$
  \Delta p_t\in\mathcal D,\qquad p_t=\Pi_{\mathcal P}(p_{t-1}+\Delta p_t).
  $$

- **Repetições:** usar o painel de sementes da etapa 1, ampliado se a estimativa de ruído exigir. A mesma trajetória de política é aplicada a todas as suas sementes.
- **Treinamento:** reunir transições das duas etapas e estimar $P_\phi(s_{t+1}\mid s_{0:t},p_{0:t},z_{0:t})$, com perda de previsão recursiva de até 12 trimestres: $\sum_{k=1}^{12}w_k\,\mathrm{NLL}(s_{t+k};\hat\mu_{t+k},\hat\Sigma_{t+k})$.
- **Validação:** reservar configurações e trajetórias completas, mantendo suas sementes no mesmo conjunto; testar também com novas sementes. Comparar previsões fixas e após mudanças com novas execuções do BeforeIT.

## Pseudocódigo

```text
fixar calibração, indicadores e limites fiscais
para etapa em [fixa, variável]:
    amostrar políticas: p[t] = p[i] (fixa) ou trajetória limitada (variável)
    para cada política i e semente j:
        iniciar BeforeIT; observar s[0]
        para t = 0,...,11:
            aplicar p[t]; avançar um trimestre; observar s[t+1]
            salvar (etapa, i, j, t, s[t], p[t], choque[t], s[t+1])
        registrar falhas e trajetória completa
separar treino/validação/teste por política ou trajetória, nunca por linha
```

- **Registro mínimo:** PIB real, consumo, investimento, desemprego, inflação, dívida/PIB, receita, política vigente e gasto público planejado e realizado; guardar configuração inicial, semente, falhas e versão da calibração. Nenhum resultado de $t+1$ entra nos atributos usados para prevê-lo.
- **Implementação:** `government-rl/government_policy.jl` já aplica $\tau^{INC}$, $\theta^{UB}$ e $m^G$; incluir `model.prop.tau_VAT` no mesmo ponto de decisão antes de gerar o dataset completo.
