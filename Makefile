VERSION = 0.3
DESTDIR = lua-check-hyphen
DOCDEST = $(DESTDIR)/doc

DOCNAME = luacheckhyphenmanual

DATE_ISO = $(shell date +"%F")
DATE_TEX = $(shell date +"%Y\/%m\/%d")

all:
	@echo "make: dist doc zip clean"

dist: doc
	mkdir -p $(DESTDIR)
	mkdir -p $(DOCDEST)
	cp README.md $(DOCDEST)
	cp lua-check-hyphen.sty $(DESTDIR)
	cp lua-check-hyphen.lua $(DESTDIR)
	cp tmp/$(DOCNAME).tex tmp/$(DOCNAME).pdf $(DOCDEST)
	cp sample.pdf sample.tex $(DOCDEST)
	perl -pi -e 's/(luachekchyphenversion)\{.*\}/$$1\{$(VERSION)\}/' $(DESTDIR)/lua-check-hyphen.sty
	perl -pi -e 's/(luachekchyphenpkgdate)\{.*\}/$$1\{$(DATE_TEX)\}/' $(DESTDIR)/lua-check-hyphen.sty
	perl -pi -e 's/(^-- Version:).*/$$1 $(VERSION)/' $(DESTDIR)/lua-check-hyphen.lua
	perl -pi -e 's/(Package version:).*/$$1 $(VERSION)/' $(DOCDEST)/README.md
	rm -f $(DESTDIR)/README
	( cd $(DESTDIR) ; ln -s doc/README.md README )


doc: sample.pdf
	mkdir -p tmp
	rm -rf tmp/*
	cp luacheckhyphenmanual.tex tmp
	perl -pi -e 's/(pkgversion)\{.*\}/$$1\{$(VERSION)\}/' tmp/luacheckhyphenmanual.tex
	cp sample-crop.pdf tmp
	( cd tmp ; lualatex luacheckhyphenmanual.tex)
	( cd tmp ; lualatex luacheckhyphenmanual.tex)


sample.pdf: sample.tex
	lualatex sample.tex
	pdfcrop --margins "1 1 1 1" sample.pdf

clean:
	-rm -rf tmp $(DESTDIR)
	-rm sample.pdf sample-crop.pdf
	-rm $(DOCNAME).aux $(DOCNAME).log $(DOCNAME).out $(DOCNAME).pdf $(DOCNAME).toc
	-rm sample.aux sample.log sample.uhy

zip: clean dist
	tar czvf lua-check-hyphen-$(VERSION).tgz $(DESTDIR)/*
