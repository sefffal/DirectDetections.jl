

export sample_priors
sample_priors(planet::Planet) = rand.(ComponentArray(planet.priors.priors))
sample_priors(planet::Planet,N) = [sample_priors(planet) for _ in 1:N]


function sample_priors(system::System)
    sampled = ComponentVector(
        merge(NamedTuple(rand.(ComponentArray(system.priors.priors))),
        # (;planets=[sample_priors(planet) for planet in system.planets])
        (;planets=namedtuple(collect(keys(system.planets)), [
            ComponentArray(NamedTuple([k=>v for (k,v) in pairs(NamedTuple(sample_priors(planet)))]))
            for planet in system.planets
        ]))
    ))
    return getdata(sampled)
end

sample_priors(system::System,N) = [sample_priors(system) for _ in 1:N]




# function resolve_deterministic(system::System, θ)
#     if isnothing(system.deterministic)
#         θ_resolved = NamedTuple(θ)
#     else
#         resolved_values = map(values(system.deterministic.variables)) do func
#             val = func(θ)
#         end
#         θ_resolved = merge(
#             NamedTuple(θ),
#             namedtuple(keys(system.deterministic.variables), resolved_values)
#         )
#     end

#     resolved_planets = map(keys(system.planets)) do key
#         θ_planet = θ.planets[key]
#         planet_model = system.planets[key]

#         θ_planet_resolved = NamedTuple()
#         if !isnothing(planet_model.deterministic)
#             for (key, func) in pairs(planet_model.deterministic.variables)
#                 val = func(θ_resolved, θ_planet)
#                 θ_planet_resolved = merge(θ_planet_resolved, NamedTuple{(key,), Tuple{eltype(θ)}}(val))
#             end
#         end
#         return merge(θ_planet_resolved, NamedTuple(θ_planet))
#     end
#     resolved_planets_nt = namedtuple([pl.name for pl in system.planets], resolved_planets)
#     θ_resolved_complete = merge(θ_resolved, (;planets=resolved_planets_nt))
#     return ComponentVector(θ_resolved_complete)
# end

# @generated function resolve_deterministic(planet::Planet{TDetermine}, θ_sys, θ_pl) where TDetermine
#     if TDetermine != Nothing
#         keys, funcs = _determinekeysvals(TDetermine)
#         body = Expr[]
#         for key in keys
#             ex = :(planet.deterministic.variables.$key(θ_sys,θ_pl))
#             push!(body, ex)
#         end
#         NTType = NamedTuple{keys}
#         ex = :(
#             merge($NTType($(body...)), NamedTuple(θ))
#         )
#         return ex
#     end
#     return θ
# end


# function make_resolve_deterministic(planet::Planet)

#     body = Expr[]

#     dkeys = keys(planet.deterministic.variables)
#     funcs = values(planet.deterministic.variables)
#     for (key,func) in zip(dkeys, funcs)
#         ex = :($key = $func(θ_sys, θ_pl))
#         push!(body, ex)
#     end

#     ex = :(function (θ_sys, θ_pl)
#         return merge(
#             (;$(body...)),
#             NamedTuple(θ_pl)
#         )
#     end)

#     ln_prior = @RuntimeGeneratedFunction(ex)
#     return ln_prior
# end
# function make_resolve_deterministic(system::System)

#     body = Expr[]

#     dkeys = keys(system.deterministic.variables)
#     funcs = values(system.deterministic.variables)
#     for (key,func) in zip(dkeys, funcs)
#         ex = :($key = $func(θ))
#         push!(body, ex)
#     end

#     ex = :(function (θ)
#         return merge(
#             (;$(body...)),
#             NamedTuple(θ)
#         )
#     end)

#     ln_prior = @RuntimeGeneratedFunction(ex)
#     return ln_prior
# end




# Instead of just calling mean for the distributions, we sample and then take the mean of the data.
# This does add a little jitter, but some distributions do not directly define the mean function!
# Specifically, truncated(InverseGamma()) does not work, and this is very useful.
# mean_priors(planet::Planet) = Statistics.mean.(Statistics.rand.(planet.priors.priors,1000))
function mean_priors(system::System)
    priors_all = ComponentVector(;
        NamedTuple(system.priors.priors)...,
        planets=[planet.priors.priors for planet in system.planets]
    )
    # return Statistics.mean.(Statistics.rand.(priors_all,1000))
    return Statistics.mean.(priors_all)
end


function guess_starting_position(system, N=500_000)

    @info "Guessing a good starting location by sampling from priors" N
    # TODO: this shouldn't have to allocate anything, we can just loop keeping the best.
    θ = sample_priors(system, N)
    arr2nt = DirectDetections.make_arr2nt(system) 
    θr = arr2nt.(θ)

    posts = zeros(N)
    ln_prior = make_ln_prior(system)
    arr2nt = DirectDetections.make_arr2nt(system) 
    Threads.@threads for i in eachindex(posts)
        θ_res = arr2nt(θ[i])
        posts[i] = ln_prior(θ[i]) + ln_like(θ_res, system)
    end
    # posts = map(eachrow(A)) do c
    #     DirectDetections.ln_post(ComponentVector(c, ax), system)
    # end
    mapv,mapi = findmax(posts)
    best = θ[mapi]
    
    # @info "Found good location" mapv best=NamedTuple(best)

    return best
end



function construct_elements(θ_system, θ_planet)
    return KeplerianElements((;
        θ_system.μ,
        θ_system.plx,
        θ_planet.i,
        θ_planet.Ω,
        θ_planet.ω,
        θ_planet.e,
        θ_planet.τ,
        θ_planet.a,
    ))
end
function construct_elements(θ_system, θ_planet, i)
    return KeplerianElements((;
        μ=θ_system.μ[i],
        plx=θ_system.plx[i],
        i=θ_planet.i[i],
        Ω=θ_planet.Ω[i],
        ω=θ_planet.ω[i],
        e=θ_planet.e[i],
        τ=θ_planet.τ[i],
        a=θ_planet.a[i],
    ))
end

function construct_elements(chain::Chains, planet_key::Union{String,Symbol}, i::Integer)
    pk = string(planet_key)
    return KeplerianElements((;
        μ=chain["μ"][i],
        plx=chain["plx"][i],
        i=chain[pk*"[i]"][i],
        Ω=chain[pk*"[Ω]"][i],
        ω=chain[pk*"[ω]"][i],
        e=chain[pk*"[e]"][i],
        τ=chain[pk*"[τ]"][i],
        a=chain[pk*"[a]"][i],
    ))
end

function construct_elements(chain::Chains, planet_key::Union{String,Symbol}, ii::AbstractArray{<:Integer})
    pk = string(planet_key)
    μs=chain["μ"]
    plxs=chain["plx"]
    is=chain[pk*"[i]"]
    Ωs=chain[pk*"[Ω]"]
    ωs=chain[pk*"[ω]"]
    es=chain[pk*"[e]"]
    τs=chain[pk*"[τ]"]
    as=chain[pk*"[a]"]
    return map(ii) do i
        KeplerianElements((;
            μ=μs[i],
            plx=plxs[i],
            i=is[i],
            Ω=Ωs[i],
            ω=ωs[i],
            e=es[i],
            τ=τs[i],
            a=as[i],
        ))
    end
end




function mcmc(
    system::System;
    burnin,
    numwalkers,
    numsamples_perwalker,
    thinning = 1,
    squash = true,
)
    ln_post(θ) = ln_prior(θ, system) + ln_like(θ, system)
 
    # ln_prior_system_specialized = make_ln_prior(θ, system)
    # ln_post(θ) = ln_prior_system_specialized(θ, system) + ln_like(θ, system)

    @info "Finding starting point"
    initial_walkers = [sample_priors(system) for _ in 1:numwalkers]

    # Convert the initial walkers into static arrays for stack allocation.
    # This messy line should have no impact on the semantics of the code.
    initial_walkers_static = [
        ComponentVector{SVector{length(cv)}}(; NamedTuple(cv)...) for cv in initial_walkers
    ]

    # Run the MCMC
    thetase, _accept_ratioe = KissMCMC.emcee(
        ln_post,
        initial_walkers_static;
        nburnin = burnin * numwalkers,
        use_progress_meter = true,
        nthin = thinning,
        niter = numsamples_perwalker * numwalkers,
    )

    # Convert the output into an MCMCChains.Chain.
    # Use reinterpret to avoid re-allocating all that memory
    if squash
        thetase′, _ = KissMCMC.squash_walkers(thetase, _accept_ratioe)
        reinterptted = reinterpret(reshape, eltype(first(thetase′)), thetase′)
        chains = ComponentArray(collect(eachrow(reinterptted)), getaxes(thetase′[1]))
    else
        matrix_paramxstep_per_walker = [reinterpret(reshape, eltype(first(θ)), θ) for θ in thetase]
        A = reshape(
            mapreduce(θ->reinterpret(reshape, eltype(first(θ)), θ), hcat, thetase),
            (length(thetase[1][1]), :, numwalkers,)
        )
        ax = getaxes(thetase[1][1])
        chains = ComponentArray(collect(eachslice(A,dims=1)), ax)
    end

    return chains
end




# Fallback when no random number generator is provided (as is usually the case)
function hmc(system::System, target_accept=0.9; kwargs...)
    return hmc(Random.default_rng(), system, target_accept; kwargs...)
end

function hmc(
    rng::Random.AbstractRNG,
    system::System, target_accept=0.75;
    adaptation,
    iterations,
    tree_depth=10,
    include_adapatation=false,
    burnin=0,
    initial_samples=50_000,
    initial_parameters=nothing,
    step_size=nothing,
    progress=true
)

    # Choose parameter dimensionality and initial parameter value
    initial_θ_0 = sample_priors(system)
    D = length(initial_θ_0)

    ln_prior_transformed = make_ln_prior_transformed(system)
    arr2nt = DirectDetections.make_arr2nt(system) 

    priors_vec = _list_priors(system)

    # # Capture these variables in a let binding to improve performance
    # ℓπ = let system=system, ln_prior=ln_prior, arr2nt=arr2nt
    #     function (θ)
    #         θ_res = arr2nt(θ)
    #         ll = ln_prior(θ) + ln_like(θ_res, system)
    #         return ll
    #     end
    # end
    # Capture these variables in a let binding to improve performance
    ℓπ = let system=system, ln_prior_transformed=ln_prior_transformed, arr2nt=arr2nt, priors_vec=priors_vec
        function (θ_t)
            # Transform back from the unconstrained support to constrained support for the likelihood function
            θ = Bijectors.invlink.(priors_vec, θ_t)
            θ_res = arr2nt(θ)
            ll = ln_prior_transformed(θ) + ln_like(θ_res, system)
            return ll
        end
    end

    if isnothing(initial_parameters)
        initial_θ = guess_starting_position(system,initial_samples)
    else
        initial_θ = initial_parameters
    end


    # Transform from constrained support to unconstrained support
    initial_θ_t = Bijectors.link.(priors_vec, initial_θ)

    # Define a Hamiltonian system
    metric = DenseEuclideanMetric(D)
    hamiltonian = Hamiltonian(metric, ℓπ, ForwardDiff)
    # hamiltonian = Hamiltonian(metric, ℓπ, ℓπ_grad)


    if !isnothing(step_size)
        initial_ϵ = step_size
    else
        initial_ϵ = find_good_stepsize(hamiltonian, initial_θ_t)
        @info "Found initial stepsize" initial_ϵ
    end


    integrator = Leapfrog(initial_ϵ)
    # integrator = TemperedLeapfrog(initial_ϵ, 1.05)


    # # We have change some parameters when running with image data
    if !isnothing(system.images) && target_accept > 0.6 && isnothing(step_size)
        @warn "Sampling from images with target accept greater than 0.6. This may lead to insufficient exploration."
    end

    mma = MassMatrixAdaptor(metric)
    if isnothing(step_size)
        @info "Will adapt step size and mass matrix"
        ssa = StepSizeAdaptor(target_accept, integrator)
        adaptor = StanHMCAdaptor(mma, ssa) 
    else
        @info "Will adapt mass matrix only"
        adaptor = MassMatrixAdaptor(metric)
    end

    model = AdvancedHMC.DifferentiableDensityModel(ℓπ, ForwardDiff)

    # κ = NUTS{MultinomialTS,GeneralisedNoUTurn}(integrator, max_depth=tree_depth) 
    # κ = NUTS{SliceTS, StrictGeneralisedNoUTurn}(integrator, max_depth=tree_depth) 
    

    # Had some good results with this one:
    # κ = NUTS{MultinomialTS, StrictGeneralisedNoUTurn}(integrator, max_depth=tree_depth) 

    κ = NUTS(integrator, max_depth=tree_depth) 
    sampler = AdvancedHMC.HMCSampler(κ, metric, adaptor)


    # logger = SimpleLogger(stdout, Logging.Error)

    AbstractMCMC.setprogress!(true)
    start_time = time()
    # mc_samples = with_logger(logger) do
        mc_samples = sample(
            rng, model, κ, metric, adaptor, iterations;
            nadapts = adaptation,
            init_params = initial_θ_t,
            progress=progress,
            verbose=false,
            discard_initial = adaptation + burnin,
        )
        # mc_samples =sample(
        #     rng,
        #     model,
        #     sampler,
        #     iterations;
        #     nadapts = adaptation,
        #     init_params = initial_θ_t,
        #     discard_initial = adaptation,
        #     progress=progress,
        #     verbose=false
        # )
    # end
    stop_time = time()

    stat = map(s->s.stat, mc_samples)
    logpost = map(s->s.z.ℓπ.value, mc_samples)
    # samples = map(s->s.z.θ, mc_samples)

    # Transform samples back to constrained support
    samples = map(mc_samples) do s
        θ_t = s.z.θ
        θ = Bijectors.invlink.(priors_vec, θ_t)
        return θ
    end


    @info "Resolving deterministic variables"
    chain_res = arr2nt.(samples)
    @info "Constructing chains"
    mcmcchain = result2mcmcchain(system, chain_res)
    mcmcchain_with_info = MCMCChains.setinfo(
        mcmcchain,
        (;start_time, stop_time, model=system)
    )

    mean_accept = mean(getproperty.(stat, :acceptance_rate))
    num_err_frac = mean(getproperty.(stat, :numerical_error))
    mean_tree_depth = mean(getproperty.(stat, :tree_depth))
    max_tree_depth_frac = mean(getproperty.(stat, :tree_depth) .== tree_depth)

    println("Sampling report:")
    @show mean_accept
    @show num_err_frac
    @show mean_tree_depth
    @show max_tree_depth_frac

    # Report some warnings if sampling did not work well
    if num_err_frac == 1.0
        @error "Numerical errors encountered in ALL iterations. Check model and priors."
    elseif num_err_frac > 0.1
        @warn "Numerical errors encountered in more than 10% of iterations" num_err_frac
    end
    if max_tree_depth_frac > 0.1
        @warn "Maximum tree depth hit in more than 10% of iterations (reduced efficiency)" max_tree_depth_frac
    end

    return (;
        chain=mcmcchain_with_info,
        stats=stat,
        logpost,
        adaptor
    )
end

include("tempered-sampling.jl")


"""
Convert a vector of component arrays returned from sampling into an MCMCChains.Chains
object.
"""
function result2mcmcchain(system, chains_in_0)
    chains_in = ComponentArray.(chains_in_0)
    # `system` not currently used, but a more efficient/robust mapping in future might require it.

    # There is a specific column name convention used by MCMCChains to indicate
    # that multiple parameters form a group. Instead of planets.X.a, we adapt our to X[a] 
    # accordingly
    flattened_labels = replace.(labels(first(chains_in)), r"planets\.([^\.]+).([^\.]+)" => s"\1[\2]")
    c = Chains(
        reduce(vcat, getdata.(chains_in)'),
        flattened_labels
    )
    return c
end

# """
#     planet_keys(system, key)

# For planet `key`, return the column names used in the output chains.

# Examples:
# ```julia-repl
# julia> planet_keys(system, :X)
# 7-element Vector{String}:
#  "f[a]"
#  "f[e]"
#  "f[τ]"
#  "f[ω]"
#  "f[i]"
#  "f[Ω]"
#  "f[Keck_L′]"
# ```
# """
# function planet_keys(system, key)
#     # There is a specific column name convention used by MCMCChains to indicate
#     # that multiple parameters form a group. Instead of planets.X.a, we adapt our to X[a] 
#     # accordingly
    
#     θ = sample_priors(system)
#     θ_r = resolve_deterministic(system, θ)

#     flattened_labels = replace.(labels(θ_r), r"planets\.([^\.]+).([^\.]+)" => s"\1[\2]")

#     planet_key_start = string(key) * "["
#     return filter(startswith(planet_key_start), flattened_labels)
# end
# export planet_keys