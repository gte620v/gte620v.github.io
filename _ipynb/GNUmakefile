.PHONY: build
.DEFAULT_GOAL := build

build:
	find . -name *.ipynb | xargs jupyter-nbconvert --to jekyll --output-dir ../_posts/
