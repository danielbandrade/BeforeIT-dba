# Dataset de política fiscal fixa

- Plano de geração: `fiscal-policy-dataset-plan.md`. Plano de treinamento: `fiscal-policy-surrogate-plan.md`.

- Edite `experiment.toml` para definir escala, domínio fiscal e número de runs. Os limites são exploratórios, centrados na calibração austríaca.
- Na raiz do repositório, execute:

  ```sh
  julia --project=. dba-studies/machine-learning/fiscal-policy-dataset/generate_dataset.jl
  ```

- Cada configuração usa a mesma calibração inicial e o mesmo painel de sementes. `tau_INC`, `tau_VAT`, `theta_UB` e `log_m_G` são aplicados após a inicialização e permanecem constantes nos 12 trimestres.
- A pasta de saída contém `configurations.csv` (políticas e partições), `trajectories/*.csv` (uma trajetória por semente), `runs.csv` (sucessos e falhas), `observations.csv` (todas as trajetórias), `summary.csv` (média e erro padrão por configuração e trimestre), `metadata.toml` e cópias do código e da configuração utilizados.
- Para retomar runs incompletos, execute o mesmo comando com os mesmos arquivos. Runs concluídos são preservados; falhas são tentadas novamente. As partições de treino, validação e teste são atribuídas por configuração.
- A configuração padrão usa `source = "bundled"` e `scale = 0.001`, sem download. Para a escala integral, use `source = "zenodo"` e `scale = 1.0`; os 500 runs podem levar várias dezenas de horas.

## Experimento ampliado

- `experiment-expanded.toml` define **500 configurações × 10 sementes = 5.000 runs**, mantendo a calibração austríaca e a escala `0.001`. O piloto permanece em `experiments/austria-scale-0.001`; a expansão é salva separadamente em `experiments/austria-scale-0.001-expanded`.
- As faixas ampliadas são `tau_INC` ±0,03, `tau_VAT` ±0,03, `theta_UB` ±0,075 e multiplicador de gasto público entre 0,925 e 1,075. O número de configurações cresceu aproximadamente na mesma proporção que o volume do domínio fiscal (cerca de 5 vezes).
- Para executar ou retomar, na raiz do repositório:

  ```sh
  julia --project=. dba-studies/machine-learning/fiscal-policy-dataset/generate_dataset.jl dba-studies/machine-learning/fiscal-policy-dataset/experiment-expanded.toml
  ```

- O gerador retoma runs concluídos no mesmo experimento; `summary.csv` e `observations.csv` são atualizados quando todos os runs terminam.
- A execução ampliada foi concluída e verificada; resultados e limitações estão em [expanded-run-report.md](expanded-run-report.md).

## Treinar o surrogate em Python

- O notebook [train_surrogate.ipynb](train_surrogate.ipynb) implementa o plano de treinamento. `EXPERIMENT_NAME` seleciona o experimento; o padrão é a versão ampliada. Para o piloto, use `austria-scale-0.001`.
- Na raiz do repositório, use Python 3.11 ou superior e crie o ambiente: `python3 -m venv dba-studies/machine-learning/fiscal-policy-dataset/.venv`.
- Instale as dependências: `dba-studies/machine-learning/fiscal-policy-dataset/.venv/bin/python -m pip install -r dba-studies/machine-learning/fiscal-policy-dataset/requirements.txt`.
- Abra o notebook com `dba-studies/machine-learning/fiscal-policy-dataset/.venv/bin/jupyter lab dba-studies/machine-learning/fiscal-policy-dataset/train_surrogate.ipynb` e execute as células em ordem. O notebook também pode ser executado a partir da pasta em que está salvo.
- Os resultados do treino são gravados em `experiments/austria-scale-0.001/surrogate/` (pasta ignorada pelo Git). O notebook recusa dados incompletos e consulta o teste apenas após escolher o modelo na validação.
