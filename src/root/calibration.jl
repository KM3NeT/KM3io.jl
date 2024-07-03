"""

A data structure to hold orientations data. This struct should be instantiated by
`Base.read(filename, Orientations)`.

"""
struct Orientations
    module_ids::Set{Int}
    times::Dict{Int, Vector{Float64}}
    quaternions::Dict{Int, Vector{Quaternion}}
end
function Base.show(io::IO, o::Orientations)
    min_t = Inf
    max_t = -Inf
    for times in values(o.times)
        _min_t, _max_t = extrema(times)
        if _min_t < min_t
            min_t = _min_t
        end
        if _max_t > max_t
            max_t = _max_t
        end
    end
    t₁ = unix2datetime(min_t)
    t₂ = unix2datetime(max_t)
    print(io, "Orientations of $(length(o.module_ids)) modules ($(t₁) to $(t₂))")
end
function (o::Orientations)(module_id::Integer, time::Real)
    times = o.times[module_id]
    (time < first(times) || time > last(times)) && error("The requested time is outside of the range of the orientations data.")

    idx2 = searchsortedfirst(times, time)
    q2 = o.quaternions[module_id][idx2]
    (idx2 >= length(times) || idx2 == 1) && return q2
    idx1 = idx2 - 1
    q1 = o.quaternions[module_id][idx1]

    t1 = times[idx1]
    t2 = times[idx2]
    Δt = t2 - t1

    Δt == 0.0 && return q1

    t = (time - t1) / Δt

    slerp(q1, q2, t)
end
(o::Orientations)(module_id::Integer) = (t=o.times[module_id], q=o.quaternions[module_id])


function Base.read(filename::AbstractString, T::Type{Orientations})
    f = UnROOT.ROOTFile(filename)
    module_ids = Set{Int}()
    quaternions = Dict{Int, Vector{Quaternion}}()
    times = Dict{Int, Vector{Float64}}()
    for (module_id, t, a, b, c, d) in zip([UnROOT.LazyBranch(f, "ORIENTATION/ORIENTATION/$(b)") for b in ["id", "t", "JCOMPASS::JQuaternion/a", "JCOMPASS::JQuaternion/b", "JCOMPASS::JQuaternion/c", "JCOMPASS::JQuaternion/d"]]...)
        if !(module_id ∈ module_ids)
             push!(module_ids, module_id)
            quaternions[module_id] = Quaternion[]
            times[module_id] = Float64[]
        end
        push!(quaternions[module_id], Quaternion(a, b, c, d))
        push!(times[module_id], t)
    end
    T(module_ids, times, quaternions)
end

"""
A compass with yaw, pitch and roll.
"""
struct Compass
    yaw::Float64
    pitch::Float64
    roll::Float64
end

"""

Initialises a [`Compass`](@ref) from a [`Quaternion`](@ref).

"""
function Compass(q::Quaternion)
    yaw = -atan(2.0 * (q.q0 * q.qz + q.qx * q.qy), 1.0 - 2.0 * (q.qy * q.qy + q.qz * q.qz))
    sp = 2.0 * (q.q0 * q.qy - q.qz * q.qx)

    if (sp >= +1.0)
        pitch = asin(+1.0)
    elseif (sp <= -1.0)
        pitch = asin(-1.0)
    else
        pitch = asin(sp)
    end

    roll = -atan(2.0 * (q.q0 * q.qx + q.qy * q.qz), 1.0 - 2.0 * (q.qx * q.qx + q.qy * q.qy))

    Compass(yaw, pitch, roll)
end
