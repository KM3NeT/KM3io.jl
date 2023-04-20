# Examples

## Offline data

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
print(f.online)
```

and the offline tree holds our 10 MC events:

```@example 1
print(f.offline)
```
