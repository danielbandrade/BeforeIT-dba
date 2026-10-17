# Dataset de política fiscal fixa

- Edite `experiment.toml` para definir escala, domínio fiscal e número de runs. Os limites são exploratórios, centrados na calibração austríaca.
- Na raiz do repositório, execute:

  ```sh
  julia --project=. dba-studies/machine-learning/fiscal-policy-dataset/generate_dataset.jl
  ```

- Cada configuração usa a mesma calibração inicial e o mesmo painel de sementes. `tau_INC`, `tau_VAT`, `theta_UB` e `log_m_G` são aplicados após a inicialização e permanecem constantes nos 12 trimestres.
- A pasta de saída contém `configurations.csv` (políticas e partições), `trajectories/*.csv` (uma trajetória por semente), `runs.csv` (sucessos e falhas), `observations.csv` (todas as trajetórias), `summary.csv` (média e erro padrão por configuração e trimestre), `metadata.toml` e cópias do código e da configuração utilizados.
- Para retomar runs incompletos, execute o mesmo comando com os mesmos arquivos. Runs concluídos são preservados; falhas são tentadas novamente. As partições de treino, validação e teste são atribuídas por configuração.
- A configuração padrão usa `source = "bundled"` e `scale = 0.001`, sem download. Para a escala integral, use `source = "zenodo"` e `scale = 1.0`; os 500 runs podem levar várias dezenas de horas.
