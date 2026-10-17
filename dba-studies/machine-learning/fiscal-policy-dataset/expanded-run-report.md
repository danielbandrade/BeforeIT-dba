# Experimento fiscal ampliado — Áustria, escala 0,001

- Configuração: `experiment-expanded.toml`; saída: `experiments/austria-scale-0.001-expanded/`. O piloto original permanece em sua pasta.
- Faixas: `tau_INC` 0,183407–0,243407; `tau_VAT` 0,122868–0,182868; `theta_UB` 0,283582–0,433582; multiplicador de gasto público 0,925–1,075.
- Desenho: 500 políticas (400 treino, 50 validação, 50 teste), 10 sementes comuns e 12 trimestres. **105 políticas** estão dentro dos limites antigos: 83 treino, 14 validação e 8 teste.
- Execução em 17/10/2026: **5.000 runs válidos**, nenhuma falha, **60.000 observações** e **6.000 linhas de resumo**. A simulação serial levou cerca de 34 minutos entre a primeira e a última trajetória, além da inicialização e agregação. O notebook validou contagens, chaves, finitude e médias das sementes.
- Modelo escolhido pelo notebook: **Ridge quadrática**, NRMSE 0,376 na validação e **0,359 no novo teste**. PCA + GP com oito componentes obteve 0,371 na validação; o ganho de cerca de 1,1% não atingiu o critério de 5% definido antes de abrir o teste.
- No novo teste: RMSE do PIB real **462,05** nas unidades da simulação, da inflação trimestral **0,00136** e da razão dívida/PIB **0,00495**. NRMSE por região: **0,337** nas 8 políticas dentro dos limites antigos e **0,363** nas 42 políticas das novas faixas. As estimativas por região têm incerteza, sobretudo no grupo de oito políticas.
- Diagnóstico adicional nas **mesmas 10 políticas de teste do piloto**, usando o desvio padrão do treino antigo como denominador: NRMSE **0,541** com o modelo antigo e **0,508** com o novo. Esta comparação é exploratória, pois o resultado do piloto motivou a expansão; o novo teste de 50 políticas é a avaliação principal. O NRMSE 0,359 do novo teste não é diretamente comparável ao 0,541 do piloto, pois os domínios e denominadores são diferentes.
- Limites observados: inflação ainda tem NRMSE **0,996** no novo teste; **46 de 600** previsões trimestrais de desemprego ficaram abaixo de zero (mínimo −0,0116). O surrogate continua exploratório para esses indicadores.

Artefatos detalhados: `experiments/austria-scale-0.001-expanded/surrogate/` (ignorado pelo Git).
