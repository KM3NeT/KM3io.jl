build:
	julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.resolve()'

doc:
	make -C docs/

test:
	julia --project=. -e 'using Pkg; Pkg.test()'

clean:
	rm -rf docs/build/

docwatch:
	while true; do fswatch -1 docs src && make doc; done

preview:
	julia -e 'using LiveServer; serve(dir="docs/build")'


.PHONY: build doc docwatch test clean preview
