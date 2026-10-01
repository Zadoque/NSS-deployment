.PHONY: pdf clean

pdf:
	latexmk -pdf -interaction=nonstopmode -halt-on-error main.tex
	cp main.pdf arquitetura-main.pdf

clean:
	latexmk -C main.tex
	rm -f arquitetura-main.pdf
