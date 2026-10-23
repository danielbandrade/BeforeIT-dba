# Apresentação LaTeX do seminário

O arquivo `seminario.pdf` é a apresentação pronta. `seminario.tex` contém o código Beamer. O arquivo original `../seminario-scx5013.ipynb` não foi modificado.

O tema usa vermelho `#CC0100FF`, branco e preto. O texto, as fórmulas, as figuras e as tabelas vêm do notebook. Os trechos de código não aparecem nos slides. O gerador inclui imagens anexadas às células e divide imagens verticais em dois slides para manter a leitura. Ele também extrai os GIFs das saídas do notebook. Como o PDF não reproduz animações, três quadros de cada GIF aparecem nos slides; os GIFs originais estão em `assets/`. As mensagens de execução estão em `outputs/`.

Para gerar novamente a apresentação a partir do notebook, execute nesta pasta:

```sh
python3 build.py
latexmk -xelatex -interaction=nonstopmode -halt-on-error seminario.tex
```

Requisitos: Python com `lxml` e `Pillow`, Pandoc, XeLaTeX e Latexmk.
