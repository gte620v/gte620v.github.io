.PHONY: build
.DEFAULT_GOAL := build

build:
	find _ipynb -maxdepth 1 -name *.ipynb | xargs jupyter-nbconvert --to jekyll --output-dir _posts/
