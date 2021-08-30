@named X = DirectDetections.Planet(
    Priors(
        a = Normal(1, 0.2),
        e = TruncatedNormal(0.0, 0.2, 0, 1.0),
        τ = Normal(0.5, 0.5,),
        ω = Normal(0., 2π),
        i = Normal(deg2rad(20.), deg2rad(10.)),
        Ω = Normal(0., 2π),
    ),
    Astrometry(
        (epoch=5000.,  ra=1000.0, dec=250, σ_ra=100., σ_dec=100.),
        (epoch=5172.,  ra=-900.1, dec=-100., σ_ra=100., σ_dec=100.),
    )
)

@named HD82134 = System(
    Priors(
        μ = Normal(1.0, 0.01),
        plx =Normal(1000.2, 0.02),
    ),  
    X,
)

chains, stats = DirectDetections.hmc(
    HD82134;
    burnin=3_000,
    numwalkers=1,
    numsamples_perwalker=10_000
);

##
p = plotmodel(chains[1], HD82134)
plot(p,fmt=:png)