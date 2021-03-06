using DirectDetections, Distributions, Plots


@named b = Planet{KeplerianElements}(
    Variables(
        a = TruncatedNormal(1, 0.5, 0, Inf),
        e = TruncatedNormal(0.0, 0.2, 0, 1.0),
        τ = Uniform(0, 1),
        ω = UniformCircular(),
        i = Sine(),
        Ω = UniformCircular(),
    ),
    Astrometry(
        (epoch=5000.,  ra=-364., dec=-1169., σ_ra=70., σ_dec=30.),
        (epoch=5014.,  ra=-493., dec=-1104., σ_ra=70., σ_dec=30.),
        (epoch=5072.,  ra=-899., dec=-629., σ_ra=20.,  σ_dec=50.),
    ),
)

@named HD82134 = System(
    Variables(
        M =  TruncatedNormal(1.0, 0.01, 0, Inf),
        plx = TruncatedNormal(1000.2, 0.02, 0, Inf),
    ),
    b,
)

##
scatter(astrometry(b), label="Planet b Astrometry", aspectratio=1)
xlims!(-1500,1500)
ylims!(-1500,1500)
##

chain = DirectDetections.hmc(
    HD82134, 0.65,# MCMCThreads(),
    num_chains=1,
    adaptation =   5_000,
    iterations =   50_000,
    tree_depth =   12
)
##
chains = DirectDetections.chainscat(chain, chain2)
##
plotmodel(chain[3end÷4:end], color="b[i]")
xlims!(-1500,1500)
ylims!(-1500,1500)

## Or for more customized output:
using PairPlots
table = (;
    a=         chain["b[a]"],
    e=         chain["b[e]"],
    i=rad2deg.(chain["b[i]"]),
    Ω=rad2deg.(chain["b[Ω]"]),
    ω=rad2deg.(chain["b[ω]"]),
    τ=         chain["b[τ]"],
)
labels=[
    "a",
    "e",
    "i",
    "\\Omega",
    "\\omega",
    "\\tau",
]
units = [
    "(au)",
    "",
    "(\\degree)",
    "(\\degree)",
    "(\\degree)",
    "",
]
PairPlots.corner(table, labels, units)

##
cd(@__DIR__)
savefig("../docs/src/assets/astrometry-corner-plot.svg")