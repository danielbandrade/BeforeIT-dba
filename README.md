# BeforeIT-dba

Versão pessoal de **Daniel Andrade** do modelo [BeforeIT.jl](https://github.com/bancaditalia/BeforeIT.jl), destinada a estudos exploratórios de macroeconomia baseada em agentes.

> Este é um repositório independente para aprendizado e experimentação. Ele não é a distribuição oficial do BeforeIT.jl e não representa a Banca d'Italia nem os autores do projeto original.

## Objetivo

Este repositório é utilizado para:

- estudar os agentes, mercados e mecanismos internos do BeforeIT;
- documentar as condições iniciais e a dinâmica do modelo;
- desenvolver extensões e cenários contrafactuais;
- executar experimentos reproduzíveis;
- analisar resultados econômicos e distributivos.

## Estudos disponíveis

- [Mercado de apostas](dba-studies/gambling-market/): extensão que representa transferências recorrentes de renda de trabalhadores para proprietários de empresas, acompanhada de notebooks, testes e experimentos pareados.
- [Mecânica do modelo](dba-studies/model-mechanics/): mapas e explicações sobre as etapas de uma simulação.
- [Machine learning](dba-studies/machine-learning/): estudos sobre modelos substitutos e aplicações de aprendizado de máquina.
- [Experimentos de escala](dba-studies/scaling-experiments/): testes com diferentes populações de agentes.
- [Apresentações](dba-studies/course-presentations/): materiais didáticos sobre o BeforeIT.

## Instalação

O projeto requer [Julia](https://julialang.org/downloads/) 1.9 ou superior.

```bash
git clone https://github.com/danielbandrade/BeforeIT-dba.git
cd BeforeIT-dba
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## Execução básica

Abra o ambiente Julia do projeto:

```bash
julia --project=.
```

Em seguida:

```julia
import BeforeIT as Bit

model = Bit.Model(
    Bit.AUSTRIA2010Q1.parameters,
    Bit.AUSTRIA2010Q1.initial_conditions,
)

Bit.run!(model, 20)
```

Para executar o script principal diretamente:

```bash
julia --project=. main.jl
```

## Testes

```bash
julia --project=. test/runtests.jl
```

## Estrutura

```text
src/          implementação do modelo e extensões
test/         testes automatizados
data/         calibrações e condições iniciais
examples/     exemplos de uso
dba-studies/  estudos, notebooks e experimentos pessoais
```

## Projeto original

O BeforeIT.jl é um modelo macroeconômico baseado em agentes desenvolvido a partir do trabalho dos autores do projeto original. Consulte:

- [Repositório oficial](https://github.com/bancaditalia/BeforeIT.jl)
- [Documentação oficial](https://bancaditalia.github.io/BeforeIT.jl/dev/)
- [Descrição do software](https://arxiv.org/abs/2502.13267)
- [Economic forecasting with an agent-based model](https://www.sciencedirect.com/science/article/pii/S0014292122001891)

As modificações, análises e conclusões presentes neste repositório são de responsabilidade de **Daniel Andrade**.

## Licença

Este repositório preserva a licença Apache 2.0 do projeto original. Consulte [LICENSE](LICENSE).
