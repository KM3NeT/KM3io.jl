all:
	julia --project=. -e 'import Pkg; Pkg.instantiate(); Pkg.resolve()'
	julia --project=. make.jl

debug:
	julia --project=. -e 'import Pkg; Pkg.instantiate(); Pkg.resolve()'
	JULIA_DEBUG=Documenter julia --project=. make.jl

clean:
	rm -rf build/

preview:
	julia -e 'using LiveServer; serve(dir="build")'
