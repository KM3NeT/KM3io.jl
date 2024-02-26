
function extract_audio_words(buf::Vector{UInt8}, info::CLBInfoWord)::Vector{AbstractCLBAudioWord}
    if amplitudeResolution(info) != 24
        error("method was only tested with 24 bits resolution")
    end
    b8 = IOBuffer(buf)
    b16 = Vector{UInt16}(undef,trunc(Int,length(buf)/2))
    b64 = Vector{UInt64}(undef,trunc(Int,length(buf)/8))
    read!(b8,b16)
    seek(b8,0)
    read!(b8,b64)
    b16 = ntoh.(b16)
    b64 = ntoh.(b64)
    for i in 1:16
        println(i," 0x",string(buf[i],base=16))
    end
    println("-------------")
    for i in 1:8
        println(i," 0x",string(b16[i],base=16))
    end
    println("-------------")
    l_mask1=0x00FFFFFF00000000
    l_mask2=0x00000000FFFFFF00
    l_max=2147483648.;

    for i in 1:4
        ch1 = ((b64[i] & l_mask1 ) >> 24)
        ch2 = ((b64[i] & l_mask2 ))

        println(i," 0x -> ",string(b64[i],base=16)," ch1 ",string(ch1,base=16), " ch2 ",string(ch2,base=16))
    end
    return []

end
