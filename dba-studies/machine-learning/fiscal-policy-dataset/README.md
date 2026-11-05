# Dataset de política fiscal fixa

- Plano de geração: `fiscal-policy-dataset-plan.md`. Plano de treinamento: `fiscal-policy-surrogate-plan.md`.

- Edite `experiment.toml` para definir escala e número de runs. O domínio fiscal atual vai de zero ao dobro de cada valor da calibração austríaca.
- Na raiz do repositório, execute:

  ```sh
  julia --project=. dba-studies/machine-learning/fiscal-policy-dataset/generate_dataset.jl
  ```

- Cada configuração usa a mesma calibração inicial e o mesmo painel de sementes. `tau_INC`, `tau_VAT`, `theta_UB` (seguro-desemprego) e `spending_multiplier` são aplicados após a inicialização e permanecem constantes nos 12 trimestres.
- Para conferir as fronteiras de zero: `julia --project=. dba-studies/machine-learning/fiscal-policy-dataset/test/runtests.jl`.
- A pasta de saída contém `configurations.csv` (políticas e partições), `trajectories/*.csv` (uma trajetória por semente), `runs.csv` (sucessos e falhas), `observations.csv` (todas as trajetórias), `summary.csv` (média e erro padrão por configuração e trimestre), `metadata.toml` e cópias do código e da configuração utilizados.
- Para retomar runs incompletos, execute o mesmo comando com os mesmos arquivos. Runs concluídos são preservados; falhas são tentadas novamente. As partições de treino, validação e teste são atribuídas por configuração.
- A configuração padrão usa `source = "bundled"` e `scale = 0.001`, sem download. Para a escala integral, use `source = "zenodo"` e `scale = 1.0`; os 500 runs podem levar várias dezenas de horas.

## Experimento ampliado

- `experiment-expanded.toml` define **500 configurações × 10 sementes = 5.000 runs**, mantendo a calibração austríaca, a escala `0.001` e o mesmo domínio do piloto. O novo piloto é salvo em `experiments/austria-scale-0.001-zero-to-double`; a expansão, em `experiments/austria-scale-0.001-zero-to-double-expanded`. Os experimentos anteriores permanecem nas pastas originais.
- As quatro entradas são amostradas diretamente de zero ao dobro do valor de referência. O desenho mantém política base, oito fronteiras individuais e LHS para as demais configurações.
- Para executar ou retomar, na raiz do repositório:

  ```sh
  julia --project=. dba-studies/machine-learning/fiscal-policy-dataset/generate_dataset.jl dba-studies/machine-learning/fiscal-policy-dataset/experiment-expanded.toml
  ```

- O gerador retoma runs concluídos no mesmo experimento; `summary.csv` e `observations.csv` são atualizados quando todos os runs terminam.
- A nova repetição foi concluída e avaliada em [zero-to-double-run-report.md](zero-to-double-run-report.md).
- O relatório [expanded-run-report.md](expanded-run-report.md) descreve a expansão anterior, de intervalos estreitos.

## Treinar o surrogate em Python

- O notebook [train_surrogate.ipynb](train_surrogate.ipynb) implementa o plano de treinamento. `EXPERIMENT_NAME` seleciona o experimento; o padrão é a nova versão ampliada. Para o novo piloto, use `austria-scale-0.001-zero-to-double`.
- Na raiz do repositório, crie o ambiente com Python 3.12 fora do Git: `python3.12 -m venv ../.venvs/beforeit-fiscal-policy`.
- Instale as dependências: `../.venvs/beforeit-fiscal-policy/bin/python -m pip install -r dba-studies/machine-learning/fiscal-policy-dataset/requirements.txt`.
- Para usar no VS Code, abra `train_surrogate.ipynb` e selecione **Select Kernel → Select Another Kernel → Jupyter Kernels → Python (BeforeIT fiscal policy)**. O kernel foi registrado com `../.venvs/beforeit-fiscal-policy/bin/python -m ipykernel install --user --name beforeit-fiscal-policy --display-name "Python (BeforeIT fiscal policy)"`. Execute as células em ordem; o notebook também pode ser executado a partir da pasta em que está salvo.
- Os resultados do treino são gravados em `experiments/<EXPERIMENT_NAME>/surrogate/` (pasta ignorada pelo Git). O notebook recusa dados incompletos e consulta o teste apenas após escolher o modelo na validação.

## Análise de sensibilidade

- O notebook [sensitivity_analysis.ipynb](sensitivity_analysis.ipynb) usa por padrão a expansão de zero ao dobro. Ele compara 0%, 50%, 100%, 150% e 200% de cada parâmetro com a política base por semente, calcula associações de Spearman nos pontos LHS e mostra a evolução trimestral e mapas bivariados. O PIB é apresentado como variação percentual em relação à política base; os demais indicadores mantêm suas unidades originais.
- Os pontos de 50% e 150% são simulações adicionais, geradas com `julia --project=. dba-studies/machine-learning/fiscal-policy-dataset/generate_sensitivity_midpoints.jl`. Para o piloto, passe `dba-studies/machine-learning/fiscal-policy-dataset/experiment.toml` como argumento. Os datasets originais permanecem separados.
- Abra com o mesmo kernel Python do notebook de treino. Altere `FOCUS_METRIC` na primeira célula de código para examinar outro indicador. Tabelas e figuras são salvas em `experiments/<EXPERIMENT_NAME>/sensitivity/`.
