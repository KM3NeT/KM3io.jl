struct CHTag
    data::SVector{8, UInt8}
end
function CHTag(s::AbstractArray{T}) where {T<:UInt8}
    n = length(s)
    data = zeros(UInt8, 8)
    @inbounds for i in 1:min(8, n)
        data[i] = UInt8(s[i])
    end
    CHTag(SVector{8, UInt8}(data))
end
CHTag(s::AbstractString) = CHTag(Vector{UInt8}(s))
CHTag(s::TCPSocket) = CHTag(read(s, 8))
Base.show(io::IO, t::CHTag) = print(io, "CHTag(\"$(String(t.data))\")")


struct CHClient
    ip::IPv4
    port::UInt16
    tags::Vector{CHTag}
    socket::TCPSocket
    CHClient(ip, port, tags) = begin
        socket = connect(ip, port)
        chclient = new(ip, port, tags, socket)
        for tag in tags
            subscribe(chclient, tag)
        end
        chclient
    end
end


struct CHPrefix
    tag::CHTag
    length::UInt32
    data::SVector{16, UInt8}

    CHPrefix(tag, length::UInt32) = begin
        length_data = reinterpret(UInt8, [length]) |> reverse
        data = vcat(tag.data, length_data, zeros(UInt8, 4))
        new(tag, length, data)
    end
end
CHPrefix(tag::AbstractString, length::Integer) = CHPrefix(CHTag(tag), UInt32(length))

function CHPrefix(s::TCPSocket)
    tag = CHTag(s)
    length = reinterpret(UInt32, reverse(read(s, 4)))[1]
    read(s, 4)  # dummy bytes
    CHPrefix(tag, length)
end

Base.show(io::IO, p::CHPrefix) = begin
    print(io, "CHPrefix with tag '$(String(p.tag.data))' and length $(p.length)")
end


struct CHMessage
    prefix::CHPrefix
    data::Vector{UInt8}
end

function CHMessage(s::TCPSocket)
    prefix = CHPrefix(s)
    length = prefix.length
    data = read(s, length)
    return CHMessage(prefix, data)
end

CHMessage(c::CHClient) = CHMessage(c.socket)

Base.show(io::IO, m::CHMessage) = begin
    tag = String(m.prefix.tag)
    print(io, "CHMessage with tag '$tag' and length $(m.prefix.length)")
end



function subscribe(c::CHClient, tag::AbstractString; mode::Char='w')
    chtag = CHTag("_Subscri")
    prefix = CHPrefix(chtag, UInt32(length(tag)+3))
    message = CHMessage(prefix, Vector{UInt8}(" $mode $tag"))
    data = vcat(prefix.data, message.data)
    write(c.socket, data)
    write(c.socket, CHPrefix(CHTag("_Always"), UInt32(0x00)).data)
end

Base.close(c::CHClient) = close(c.socket)


Base.iterate(iter::CHClient) = (CHMessage(iter), iter)
Base.iterate(iter::CHClient, state) = (CHMessage(iter), iter)
