.PHONY: pdf clean

pdf:
	nix shell nixpkgs#texliveFull -c latexmk -cd -pdf -interaction=nonstopmode -halt-on-error -outdir=~/dev/nss-deployment/documentacao/ main.tex > /tmp/nss-deployment-build.log 2>&1

clean:
	rm -f main.aux main.log main.out main.toc main.fls main.fdb_latexmk main.synctex.gz main.pdf
	rm -f *.aux *.log *.out *.toc *.fls *.fdb_latexmk *.synctex.gz
