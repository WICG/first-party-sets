# This Makefile assumes you have a local install of bikeshed. Like any
# other Python tool, you install it with pip:
#
#     python3 -m pip install bikeshed && bikeshed update

# It also assumes you have doctoc installed. This is a tool that
# automatically generates Table of Contents for Markdown files. It can
# be installed like any other NPM module:
#
#    npm install -g doctoc

.PHONY: all publish clean update-explainer-toc
.SUFFIXES: .bs .html

publish: index.html

all: publish update-explainer-toc

clean:
	rm -rf build *~

update-explainer-toc: README.md Makefile
	doctoc $< > /dev/null

index.html: spec.bs Makefile
	mkdir -p build
	bikeshed --die-on=warning spec $< $@

