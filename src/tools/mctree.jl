const _PDG_NAMES = Dict{Int,String}(
    1 => "d", -1 => "d~", 2 => "u", -2 => "u~", 3 => "s", -3 => "s~",
    4 => "c", -4 => "c~", 5 => "b", -5 => "b~", 6 => "t", -6 => "t~",
    11 => "e-", -11 => "e+", 12 => "nu(e)", -12 => "nu(e)~",
    13 => "mu-", -13 => "mu+", 14 => "nu(mu)", -14 => "nu(mu)~",
    15 => "tau-", -15 => "tau+", 16 => "nu(tau)", -16 => "nu(tau)~",
    21 => "g", 22 => "gamma", 23 => "Z0", 24 => "W+", -24 => "W-",
    81 => "muon bundle",
    111 => "pi0", 211 => "pi+", -211 => "pi-",
    113 => "rho0", 213 => "rho+", -213 => "rho-",
    221 => "eta", 223 => "omega", 331 => "eta'", 333 => "phi",
    130 => "K(L)0", 310 => "K(S)0", 311 => "K0", -311 => "K0~",
    321 => "K+", -321 => "K-", 313 => "K*0", -313 => "K*0~", 323 => "K*+", -323 => "K*-",
    411 => "D+", -411 => "D-", 421 => "D0", -421 => "D0~", 431 => "D(s)+", -431 => "D(s)-",
    2212 => "p", -2212 => "p~", 2112 => "n", -2112 => "n~",
    2214 => "Delta+", -2214 => "Delta+~", 2224 => "Delta++", -2224 => "Delta++~",
    2114 => "Delta0", -2114 => "Delta0~", 1114 => "Delta-", -1114 => "Delta-~",
    3122 => "Lambda", -3122 => "Lambda~", 3222 => "Sigma+", -3222 => "Sigma+~",
    3212 => "Sigma0", -3212 => "Sigma0~", 3112 => "Sigma-", -3112 => "Sigma-~",
    3322 => "Xi0", -3322 => "Xi0~", 3312 => "Xi-", -3312 => "Xi-~",
    3334 => "Omega-", -3334 => "Omega-~",
    4122 => "Lambda(c)+", -4122 => "Lambda(c)-",
    2000000101 => "GENIE bindino",
    2000000001 => "GENIE pseudo",
)

const _ELEMENTS = (
    "H", "He", "Li", "Be", "B", "C", "N", "O", "F", "Ne", "Na", "Mg", "Al", "Si", "P",
    "S", "Cl", "Ar", "K", "Ca", "Sc", "Ti", "V", "Cr", "Mn", "Fe", "Co", "Ni", "Cu", "Zn",
)

const _TRK_STATUS_NAMES = Dict{Int,String}(
    getfield(TRKMEMBERS, n) => lowercase(string(n)[8:end])
    for n in names(TRKMEMBERS; all=true) if startswith(string(n), "TRK_ST_")
)

"""
Return a human readable name of a particle given its PDG ID. Nuclei
(`10LZZZAAAI`) are written as element symbol and mass number, e.g. `O16`.
Unknown codes are returned as `pdg(<code>)`.
"""
function pdgname(pdgid::Integer)
    pdgid = Int(pdgid)
    name = get(_PDG_NAMES, pdgid, nothing)
    !isnothing(name) && return name
    if abs(pdgid) >= 1000000000
        a = div(abs(pdgid), 10) % 1000
        z = div(abs(pdgid), 10000) % 1000
        element = 1 <= z <= length(_ELEMENTS) ? _ELEMENTS[z] : "Z$(z)_"
        return (pdgid < 0 ? "anti-" : "") * "$(element)$(a)"
    end
    "pdg($(pdgid))"
end

"""

    printmctree([io::IO,] mc_trks::AbstractVector{MCTrk})
    printmctree([io::IO,] evt::Evt)

Print the MC tracks as a tree, following the `mother_id` relations, to show how
the interaction took place. Tracks without a known mother (e.g. the primary
neutrino and the target nucleus) are printed as roots. Each line shows the track
ID, the particle name, the energy, the time and the MC status.

# Examples

```
julia> printmctree(f.offline[4211])
[0] nu(mu)  E=4506.633 GeV  t=0.000 ns  (primaryneutrino)
`-- [4] mu-  E=2754.213 GeV  t=0.000 ns  (finalstate)
[1] O16  E=14.895 GeV  t=0.000 ns  (ininuclei)
|-- [9] pi+  E=352.643 GeV  t=0.000 ns  (finalstate)
...
```
"""
printmctree(x) = printmctree(stdout, x)
printmctree(io::IO, evt::Evt) = printmctree(io, evt.mc_trks)
function printmctree(io::IO, mc_trks::AbstractVector{MCTrk})
    idx = Dict{Int,Int}()
    for (i, trk) in enumerate(mc_trks)
        get!(idx, trk.id, i)
    end
    children = [Int[] for _ in mc_trks]
    roots = Int[]
    for (i, trk) in enumerate(mc_trks)
        mother = get(idx, trk.mother_id, 0)
        if mother == 0 || mother == i
            push!(roots, i)
        else
            push!(children[mother], i)
        end
    end
    visited = falses(length(mc_trks))
    for i in roots
        _printmctree(io, mc_trks, children, visited, i, "", "")
    end
    # tracks in a mother_id cycle are not reachable from any root
    for i in eachindex(mc_trks)
        visited[i] || _printmctree(io, mc_trks, children, visited, i, "", "")
    end
    nothing
end

function _printmctree(io, mc_trks, children, visited, i, prefix, childprefix)
    visited[i] = true
    trk = mc_trks[i]
    status = get(_TRK_STATUS_NAMES, trk.status, string(trk.status))
    @printf(io, "%s[%d] %s  E=%.3f GeV  t=%.3f ns  (%s)\n", prefix, trk.id, pdgname(trk.type), trk.E, trk.t, status)
    todo = filter(c -> !visited[c], children[i])
    for (n, c) in enumerate(todo)
        islast = n == length(todo)
        _printmctree(io, mc_trks, children, visited, c,
                     childprefix * (islast ? "`-- " : "|-- "),
                     childprefix * (islast ? "    " : "|   "))
    end
end
