# Run BeforeIT: Áustria em escala 1 — 16/10/2026

## Execução

- **Comando:** `time julia --project=. dba-studies/scaling-experiments/run-scale.jl`
- **Calibração:** Áustria, 2010Q1, objeto `AT` baixado pelo script; `scale = 1`.
- **Simulação:** 12 trimestres, semente `1234`, `parallel = false`, Julia com 1 thread.
- **População calibrada:** 469.454 firmas, 4.236.625 domicílios ativos e 4.130.385 inativos.
- **Resultado salvo:** [austria-scale-1-results.jld2](austria-scale-1-results.jld2), 30.582 bytes; 13 observações (estado inicial + 12 trimestres).

| Medida | Valor |
| --- | ---: |
| Tempo da simulação (`@elapsed`) | 569,111 s = 9 min 29,11 s |
| Tempo total do comando (`time`) | 9 min 44,40 s = 584,40 s |
| CPU em modo usuário / sistema | 420,01 s / 104,32 s |
| Uso médio de CPU informado pelo `time` | 89% |
| PIB real inicial | 71.799,7 |
| PIB real final | 71.748,2727569876 |
| Variação do PIB real | −0,071626% |

- **Aviso durante o carregamento:** JLD2 reconstruiu o tipo `Main.CalibrationData` ausente do workspace. O run terminou e salvou o resultado.
- **Memória máxima do processo:** não medida pelo comando utilizado.
- **Referência de custo:** 569,111 / 12 ≈ 47,43 s por trimestre. Mantido esse tempo, 100 políticas × 5 sementes exigiriam aproximadamente 79 horas de simulação serial, sem contar calibração e gravação; as duas etapas do plano, aproximadamente 158 horas. É extrapolação de um único run.

## Hardware e ambiente

Especificações consultadas no Mac em 16/10/2026, após o run; bateria, energia e espaço livre abaixo representam essa consulta, não uma medição durante a simulação.

| Componente | Dados observados |
| --- | --- |
| Computador | MacBook Air; identificador `Mac17,3`; modelo `MDHH4LL/A` |
| CPU/SoC | Apple M5; 10 núcleos de CPU (4 de desempenho, 6 de eficiência); arquitetura `arm64` |
| GPU | Apple M5 integrada; 8 núcleos; Metal suportado |
| Memória | 16 GB |
| Armazenamento | SSD NVMe Apple `AP0512Z`, revisão `2.973,120`, TRIM ativo, unidade interna não removível |
| Volume de dados no momento da consulta | 460 GiB totais, 404 GiB usados, 19 GiB disponíveis, 96% de capacidade informada (`df -h .`) |
| Bateria | 56 ciclos; condição normal; capacidade máxima de 98%; carga de 80% na consulta |
| Energia na consulta | Adaptador AC conectado; modo de baixo consumo desligado |
| Firmware / carregador do sistema | `18000.121.3` / `18000.121.3` |
| Sistema operacional | macOS 26.5.2, build `25F84`; kernel Darwin 25.5.0 |
| Julia | 1.12.6; `Float64` e `Int64` como tipos padrão do BeforeIT |

Dados obtidos com `system_profiler` (hardware, GPU, NVMe e energia), `pmset -g batt`, `sw_vers`, `df -h .` e `julia --version`. Números de série, UUID e UDID foram omitidos porque não afetam o desempenho do run.

## Reprodutibilidade

- **Commit HEAD consultado:** `e428c80`. O script `run-scale.jl` ainda não estava versionado no momento do registro; o commit sozinho não identifica seu conteúdo.
- **SHA-256 do script:** `d94222a328b3e9d39f8f6fedf7956c98ad6db2f86691198ddb30a2c79cf55dcc`.
- **SHA-256 de `Manifest.toml`:** `1ed7f4fee4676ea1696dde996f3dcc0a104dcde177363fc4e338472d13480215`.
- **SHA-256 do resultado JLD2:** `081ff344f63c2114dde983161ff610fbf43973ac1a04740d070f610f341c8764`.
- **Metadados confirmados no JLD2:** país `Austria`, data `2010-03-31`, escala `1`, horizonte `12`, semente `1234`, tempo da simulação `569.111268125` s.
