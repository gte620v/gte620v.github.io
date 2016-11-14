.PHONY: build
.DEFAULT_GOAL := build

build:
	cd _ipynb/
	find . -name *.ipynb | xargs jupyter-nbconvert --to jekyll --output-dir ../_posts/
