# Offline data

Let's use the `KM3NeTTestData` Julia package which contains all kinds of KM3NeT
related sample files. The `datapath()` function can be used to get a path to
such a file. In the following, we will discover the `numucc.root` file which
contains 10 muon neutrino charged current interaction events.

```@example 1
using KM3io, KM3NeTTestData

f = ROOTFile(datapath("offline", "numucc.root"))
```

The `ROOTFile` is the container object which gives access to both the online and
offline tree. In this case, the online tree is empty

```@example 1
f.online
```

and the offline tree holds our 10 MC events:

```@example 1
f.offline
```

## Events

To access a single event, you can use the usual indexing syntax:

```@example 1
some_event = f.offline[5]
```

or ranges of events:

```@example 1
events = f.offline[6:9]
```

Another way to access events is given by getter function `getevent()` (which also works for online trees). If a
single number if passed, it will be treated as a regular index, just like above:

```@example 1
event = getevent(f.offline, 3)
```

when two numbers are passed, the first one is interpreted as `frame_index` and the second one as `trigger_counter`:

```@example 1
event = getevent(f.offline, 87, 2)
```

### Hits

Each event consists of a vector of hits, MC hits, tracks and MC tracks. Depending
on the file, they may be empty. They are accessible via the fields `.hit`, `.mc_hits`, `.trks` and `.mc_trks`.

Let's grab an event:

```@example 1
evt = f.offline[3]
```

and have a look at its contents:

```@example 1
evt.hits
```

Let's close this file properly:

```@example 1
close(f)
```

### Reconstructions

We pick the best reconstructed muon from the Jpp reconstruction chain using [`bestjppmuon`](@ref):

```@example 1
julia> reco = bestjppmuon(f.offline[1])
Trk (Reconstructed track)
  id: 1
  pos: Position{Float64}(-647.396, -138.621, 319.288)
  dir: Direction{Float64}(0.939, 0.269, 0.213)
  t: 8.849343007963674e7
  E: 117.28604237509933
  len: 0.0
  lik: 92.7921433955364
  rec_type: 4000
  rec_stages: Int32[1, 2, 3, 4, 5]
  fitinf: FitInformation([0.0020367251782607574, 0.0014177681261476852, -92.7921433955364, 107.0, 1141.8713789917795, 264.38698486751207, 0.3629813537326686, 11.0, 5.265362302261376, 13.45233763002935, 671.9039327646219, 0.0, 0.0, 2543.769772201125, -312.0874580760447, 31061.0, 107.0])
```

All the attributes listed in the output above are accessible directly from the returned [`Trk`](@ref) object.

Using the [Dot Syntax feature of
Julia](https://docs.julialang.org/en/v1/manual/functions/#man-vectorized) to
vectorise the `bestjppmuon` function in order to call it on each event, we get a
`Vector{Union{Missing, Trk}}` with 10 elements, the same number as events.

```@example 1
julia> recos = bestjppmuon.(f.offline)
10-element Vector{Union{Missing, Trk}}:
 Trk(1, Position{Float64}(-647.396, -138.621, 319.288), Direction{Float64}(0.939, 0.269, 0.213), 8.849343007963674e7, 117.28604237509933, 0.0, 92.7921433955364, 4000, Int32[1, 2, 3, 4, 5], FitInformation([0.0020367251782607574, 0.0014177681261476852, -92.7921433955364, 107.0, 1141.8713789917795, 264.38698486751207, 0.3629813537326686, 11.0, 5.265362302261376, 13.45233763002935, 671.9039327646219, 0.0, 0.0, 2543.769772201125, -312.0874580760447, 31061.0, 107.0]))
 Trk(1, Position{Float64}(448.985, 77.589, 514.499), Direction{Float64}(-0.733, 0.676, -0.081), 5.373024087958329e7, 4404.5483978014345, 0.0, 78.6644081591586, 4000, Int32[1, 2, 3, 4, 5], FitInformation([0.003306725805622178, 0.002094094517471032, -78.6644081591586, 94.0, 4708.163785752027, 216.62130875898578, 16.10344549704008, 19.0, 1.4697876790656463, 2.30609168258663, 550.546007964009, 0.0, 0.0, 5511.886182012078, -Inf, 18413.0, 100.0]))
 Trk(1, Position{Float64}(451.123, 251.088, 661.826), Direction{Float64}(-0.188, 0.013, -0.982), 4.128332208432634e7, 8.370062693049057, 0.0, 60.6596644718277, 4000, Int32[1, 2, 3, 4, 5], FitInformation([0.0057877124222254885, 0.003923368624980349, -60.6596644718277, 43.0, 499.72430050336106, 83.38095320764664, 0.44364387678437267, 9.0, 4.360114284655301, 22.285260195443527, 164.07852977335324, 0.0, 0.0, 1395.415421753966, -126.44893320133944, 11035.0, 44.0]))
 Trk(1, Position{Float64}(174.237, -114.606, 228.994), Direction{Float64}(-0.113, 0.936, 0.333), 4.495879182058443e7, 0.07330127409305437, 0.0, 24.707034349799443, 4000, Int32[1, 2, 3, 4, 5], FitInformation([0.015581698352185896, 0.009491461076780453, -24.707034349799443, 86.0, 103.54680875177948, 241.4350600810178, 3.266832183594016, 12.0, 0.45162569000225233, 0.45162569000225233, 87.33025897135943, 0.0, 0.0, 350.9576229641073, -248.2136281614012, 27341.0, 84.0]))
 missing
 Trk(1, Position{Float64}(207.242, 143.619, 82.590), Direction{Float64}(-0.876, -0.368, 0.311), 2.3455022487720076e7, 0.6036026973685176, 0.0, 58.70292050419075, 4000, Int32[1, 2, 3, 4, 5], FitInformation([0.005511614669452927, 0.00325807584389504, -58.70292050419075, 86.0, 208.61039120183392, 215.8892791712461, 19.681988940826766, 17.0, 10.049137840625324, 15.862244522613985, 638.673694728405, 0.0, 0.0, 667.5246931688921, -246.429763577056, 25698.0, 84.0]))
 Trk(1, Position{Float64}(-460.758, 86.850, 224.393), Direction{Float64}(-0.294, -0.212, 0.932), 7.143245883701208e7, 214.70262170620663, 0.0, 99.2362241012801, 4000, Int32[1, 2, 3, 4, 5], FitInformation([0.004248848088187865, 0.0027546709485314074, -99.2362241012801, 75.0, 1336.5233866589012, 152.22581865603968, 0.040331261525852063, 10.0, 7.010120467449694, 12.77144841888497, 426.91635316214877, 0.0, 0.0, 2816.4173012653227, -Inf, 13949.0, 75.0]))
 Trk(1, Position{Float64}(-522.582, -263.150, 434.833), Direction{Float64}(0.964, 0.090, 0.251), 7.477929535375737e7, 70.06192503795313, 0.0, 68.14060250066119, 4000, Int32[1, 2, 3, 4, 5], FitInformation([0.004101151563891158, 0.002092684350285085, -68.14060250066119, 89.0, 998.8763226712673, 211.00948573840338, 0.06024793388429752, 6.0, 15.113848244977945, 16.492757130258603, 400.40395747240143, 0.0, 0.0, 2325.3160124087863, -Inf, 22071.0, 89.0]))
 Trk(1, Position{Float64}(324.162, -203.143, 500.185), Direction{Float64}(-0.836, 0.546, -0.041), 5.409091484199188e7, 145.21733666145144, 0.0, 24.97545371522731, 4000, Int32[1, 2, 3, 4, 5], FitInformation([0.006811020599115176, 0.0042244227209283225, -24.97545371522731, 109.0, 1206.5434567400432, 297.66724828750915, 35.93515401953418, 11.0, 1.5677362278913236, 1.8863758539060305, 425.69335951076613, 0.0, 0.0, 2637.296203348022, -Inf, 29511.0, 110.0]))
 Trk(1, Position{Float64}(-436.232, 467.751, 477.869), Direction{Float64}(0.918, -0.377, -0.124), 3.1358173560490765e7, 0.00028016335410339786, 0.0, 1.8892925851353164, 4000, Int32[1, 2, 3, 4, 5], FitInformation([0.03551752160687541, 0.024596855145628996, -1.8892925851353164, 64.0, 16.28973662033325, 203.84773622910956, 118.57991684184053, 21.0, 0.43480442245182477, 0.453521290130835, 911.3305317553036, 0.0, 0.0, 58.17541786686647, -206.52204035464808, 27279.0, 68.0]))
```

!!! note

    Notice that [`bestjppmuon`](@ref) and other similar functions ([`bestaashower`](@ref), [`bestjppshower`](@ref)...) can return `missing` when there is no matching reconstructed track in an event.

### Fit Parameters

The fit parameters need a bit of special care. Since the KM3NeT offline
dataformat only stores a plain array of values due to historical reasons, we
need to know the index of a specific parameter beforehand. You should avoid
using hard-coded numbers to access the elements. Accessing `.fitinf` on any
reconstructed track will return an object of type [`FitInformation`](@ref),
which behaves like an array but takes care of the 1-based indexing nature of
Julia since the index definitions defined in the [KM3NeT
Dataformat](https://git.km3net.de/common/km3net-dataformat) are 0-based. These
index definitions are accessible under the `KM3io.FITPARAMETERS` namespace. If
you are for example interested in the `JGandalf Chi2` parameter, you can access
its value like this:

```@example 1
julia> reco.fitinf[KM3io.FITPARAMETERS.JGANDALF_CHI2]
-92.7921433955364
```


### Usr data

You can also access "usr"-data, which is a dynamic placeholder (`Dict{String,
Float64}`) to store arbitrary data. Some software store values here which are
only losely defined. Ideally, if these fields are used regulary by a software, a
proper definition in the KM3NeT dataformat should be created and added to the
according `Struct` as a field.

Here is an example how to access the "usr"-data of a single event:

```@example 1
f = ROOTFile(datapath("offline", "usr-sample.root"))

f.offline[1].usr
```

```@example 1
close(f)
```
