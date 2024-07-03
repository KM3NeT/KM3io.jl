struct Orientations
    times::Vector{Float64}
    quaternions::Vector{Quaternion}
end


function orientations(f::UnROOT.ROOTFile)
    q_out = Dict{Int, Vector{Quaternion}}()
    for (module_id, t, a, b, c, d) in zip([UnROOT.LazyBranch(f, "ORIENTATION/ORIENTATION/$(b)") for b in ["id", "t", "JCOMPASS::JQuaternion/a", "JCOMPASS::JQuaternion/b", "JCOMPASS::JQuaternion/c", "JCOMPASS::JQuaternion/d"]]...)
        if !haskey(q_out, module_id)
            q_out[module_id] = Quaternion[]
        end
        push!(q_out[module_id], Quaternion(a, b, c, d))
    end
    q_out
end
