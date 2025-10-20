all:
	julia --project=. -e 'import Pkg; Pkg.develop(path=".."); Pkg.instantiate()'
	julia --project=. make.jl

debug:
	julia --project=. -e 'import Pkg; Pkg.develop(path=".."); Pkg.instantiate()'
	JULIA_DEBUG=Documenter julia --project=. make.jl

clean:
	rm -rf build/

preview:
	julia -e 'using LiveServer; serve(dir="build")'
