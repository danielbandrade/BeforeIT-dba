# Repetição fiscal de zero ao dobro — Áustria, escala 0,001

- Execução em 04/11/2026. `experiment.toml` e `experiment-expanded.toml` usam, para cada entrada, o intervalo de **zero a duas vezes o valor calibrado**: `tau_INC` 0–0,426814845, `tau_VAT` 0–0,305736787, `theta_UB` 0–0,717164896 e `spending_multiplier` 0–2.
- A metodologia permaneceu: política base, oito fronteiras individuais e LHS no restante; 12 trimestres e sementes comuns por configuração. O piloto tem 100 políticas × 5 sementes; a expansão independente tem 500 políticas × 10 sementes, no mesmo domínio.
- Saídas: `experiments/austria-scale-0.001-zero-to-double/` e `experiments/austria-scale-0.001-zero-to-double-expanded/`. Os experimentos antigos permanecem nas pastas originais.

| Experimento | Políticas (treino/validação/teste) | Runs válidos | Observações | Falhas | Modelo escolhido | NRMSE validação | NRMSE teste |
| --- | ---: | ---: | ---: | ---: | --- | ---: | ---: |
| Piloto | 100 (80/10/10) | 500 | 6.000 | 0 | PCA + GP, 8 componentes | 0,355 | 0,372 |
| Expansão | 500 (400/50/50) | 5.000 | 60.000 | 0 | PCA + GP, 8 componentes | 0,346 | 0,374 |

- No teste ampliado, o RMSE foi **894,27** para PIB real, **0,001537** para inflação trimestral e **0,01274** para dívida/PIB. Os NRMSE correspondentes foram **0,092**, **1,161** e **0,102**. A inflação continua com erro alto em relação à variação entre políticas.
- O RMSE do PIB no teste do piloto foi **1.732,45**. Os testes têm políticas diferentes; a queda do RMSE não é uma comparação emparelhada. O NRMSE conjunto ficou praticamente igual entre os testes (0,372 e 0,374), também com denominadores de treino distintos.
- As quatro fronteiras individuais com zero foram simuladas. No piloto, duas ficaram no treino, uma na validação e uma no teste; na expansão, duas no treino e duas no teste. O NRMSE das **duas** fronteiras zero no teste ampliado foi **0,386**, contra **0,373** nas 48 políticas interiores. Duas políticas são insuficientes para uma conclusão firme sobre a fronteira.
- A política com **os quatro parâmetros simultaneamente em zero** completou 12 trimestres em cinco sementes de verificação, mas não faz parte do desenho amostral base + oito fronteiras + LHS. A fronteira `spending_multiplier = 0` apresentou consumo público planejado e realizado igual a zero em todos os trimestres. Quando não há consumo público, o índice de preços desse consumo recebe o valor neutro 1 para evitar `0/0` no cálculo do PIB real.
- No trimestre 12 da expansão, a maior média de consumo público **planejado** entre políticas foi cerca de **41,64 milhões**, enquanto a maior média do consumo **realizado** foi cerca de **55,55 mil**. O multiplicador constante incide a cada trimestre sobre a regra autorregressiva de gasto; valores próximos de 2 criam trajetórias planejadas extremas, embora o gasto realizado seja limitado pelo mercado. Esse comportamento deve ser considerado ao interpretar e usar o surrogate.
- O modelo ampliado produziu **151 previsões trimestrais de desemprego fora de [0,1]** no teste. Ele permanece exploratório para esse indicador.

Os arquivos de dados, modelos, partições, previsões e métricas detalhadas estão nas duas pastas de experimento, ignoradas pelo Git. O teste focal `test/runtests.jl` passou, assim como as checagens de contagem, status, comprimento e número de sementes dos dois datasets.
