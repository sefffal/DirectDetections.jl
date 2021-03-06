

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

    # TODO: this shouldn't have to allocate anything, we can just loop keeping the best.
    θ = sample_priors(system, N)
    arr2nt = DirectDetections.make_arr2nt(system) 

    posts = zeros(N)
    ln_prior = make_ln_prior(system)
    Threads.@threads for i in eachindex(posts)
        θ_res = arr2nt(θ[i])
        posts[i] = ln_prior(θ[i]) + ln_like(system, θ_res)
    end
    # posts = map(eachrow(A)) do c
    #     DirectDetections.ln_post(ComponentVector(c, ax), system)
    # end
    mapv,mapi = findmax(posts)
    best = θ[mapi]
    
    # @info "Found good location" mapv best=NamedTuple(best)

    return best
end

# This code works but I have not found it useful. Commenting out to remove Optim.jl dependency.
# using Optim
# function optimize_starting_position(ℓπ, initial_θ_t)

#     @info "Optimizing starting location "
#     results = optimize(θ_t-> -ℓπ(θ_t), initial_θ_t, LBFGS(), autodiff = :forward, Optim.Options(iterations=100_000, time_limit=5, allow_f_increases=true))
#     # results = optimize(θ_t-> -ℓπ(θ_t), initial_θ_t, NelderMead(), Optim.Options(iterations=100_000, time_limit=5))
#     # results = optimize(θ_t-> -ℓπ(θ_t), initial_θ_t, ParticleSwarm(), Optim.Options(iterations=100_000, time_limit=5))

#     intial_objective = ℓπ(initial_θ_t)

#     minimizer = Optim.minimizer(results)

#     @info "Starting location improved" logimprovement=(ℓπ(minimizer) - intial_objective)
#     return minimizer
# end


"""
    construct_elements(θ_system, θ_planet)

Given a named tuple for of parameters from a System (θ_system) and Planet (θ_planet),
return a `KeplerianElements` from PlanetOrbits.jl.
"""
function construct_elements(::Type{KeplerianElements}, θ_system, θ_planet)
    return KeplerianElements((;
        θ_system.M,
        θ_system.plx,
        θ_planet.i,
        θ_planet.Ω,
        θ_planet.ω,
        θ_planet.e,
        θ_planet.τ,
        θ_planet.a,
    ))
end

function construct_elements(::Type{RadialVelocityElements}, θ_system, θ_planet)
    return RadialVelocityElements((;
        θ_system.M,
        θ_planet.ω,
        θ_planet.e,
        θ_planet.τ,
        θ_planet.a,
    ))
end


"""
    construct_elements(chains, :b, 4)

Given a Chains object, a symbol matching the name of a planet, and an index,
construct a `KeplerianElements` from DirectOrbits of that planet from that
index of the chains.
"""
function construct_elements(chain::Chains, planet_key::Union{String,Symbol}, i::Union{Integer,CartesianIndex})
    pk = string(planet_key)
    if haskey(chain, :plx) && haskey(chain, Symbol(pk*"[i]")) && haskey(chain, Symbol(pk*"[Ω]"))
        return KeplerianElements((;
            M=chain["M"][i],
            plx=chain["plx"][i],
            i=chain[pk*"[i]"][i],
            Ω=chain[pk*"[Ω]"][i],
            ω=chain[pk*"[ω]"][i],
            e=chain[pk*"[e]"][i],
            τ=chain[pk*"[τ]"][i],
            a=chain[pk*"[a]"][i],
        ))
    elseif haskey(chain, :M) && haskey(chain, :rv)
        return KeplerianElements((;
            M=chain["M"][i],
            ω=chain[pk*"[ω]"][i],
            e=chain[pk*"[e]"][i],
            τ=chain[pk*"[τ]"][i],
            a=chain[pk*"[a]"][i],
        ))
    else
        error("Unrecognized columns")
    end
end

"""
    construct_elements(chains, :b, [4,5,10])

Given a Chains object, a symbol matching the name of a planet, and an array of indices,
construct a `KeplerianElements` from DirectOrbits of that planet from those indices
of the chains.
"""
function construct_elements(chain::Chains, planet_key::Union{String,Symbol}, ii::AbstractArray{<:Union{Integer,CartesianIndex}})
    pk = string(planet_key)
    if haskey(chain, :plx) && haskey(chain, Symbol(pk*"[i]")) && haskey(chain, Symbol(pk*"[Ω]"))
        Ms=chain["M"]
        plxs=chain["plx"]
        is=chain[pk*"[i]"]
        Ωs=chain[pk*"[Ω]"]
        ωs=chain[pk*"[ω]"]
        es=chain[pk*"[e]"]
        τs=chain[pk*"[τ]"]
        as=chain[pk*"[a]"]
        return map(ii) do i
            KeplerianElements((;
                M=Ms[i],
                plx=plxs[i],
                i=is[i],
                Ω=Ωs[i],
                ω=ωs[i],
                e=es[i],
                τ=τs[i],
                a=as[i],
            ))
        end
    elseif haskey(chain, Symbol("M")) && haskey(chain, Symbol("rv"))
        Ms=chain["M"]
        ωs=chain[pk*"[ω]"]
        es=chain[pk*"[e]"]
        τs=chain[pk*"[τ]"]
        as=chain[pk*"[a]"]
        return map(ii) do i
            RadialVelocityElements((;
                M=Ms[i],
                ω=ωs[i],
                e=es[i],
                τ=τs[i],
                a=as[i],
            ))
        end
    else
        error("Unrecognized chain format")
    end
end
function construct_elements(chain, planet_key::Union{String,Symbol}, ii::AbstractArray{<:Union{Integer,CartesianIndex}})
    pk = string(planet_key)
    Ms=chain[:,"M"]
    plxs=chain[:,"plx"]
    is=chain[:,pk*"[i]"]
    Ωs=chain[:,pk*"[Ω]"]
    ωs=chain[:,pk*"[ω]"]
    es=chain[:,pk*"[e]"]
    τs=chain[:,pk*"[τ]"]
    as=chain[:,pk*"[a]"]
    return map(ii) do i
        KeplerianElements((;
            M=Ms[i],
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


# Fallback when no random number generator is provided (as is usually the case)
function hmc(system::System, target_accept::Number=0.8, ensemble::AbstractMCMC.AbstractMCMCEnsemble=MCMCSerial(); kwargs...)
    return hmc(Random.default_rng(), system, target_accept, ensemble; kwargs...)
end

function hmc(
    rng::Random.AbstractRNG,
    system::System, target_accept::Number=0.8,
    ensemble::AbstractMCMC.AbstractMCMCEnsemble=MCMCSerial();
    num_chains=1,
    adaptation,
    iterations,
    thinning=1,
    discard_initial=adaptation,
    tree_depth=10,
    initial_samples=50_000,
    initial_parameters=nothing,
    step_size=nothing,
    verbosity=2,
    autodiff=ForwardDiff
)

    # Choose parameter dimensionality and initial parameter value
    initial_θ_0 = sample_priors(system)
    D = length(initial_θ_0)

    ln_prior_transformed = make_ln_prior_transformed(system)
    # ln_prior = make_ln_prior(system)
    arr2nt = DirectDetections.make_arr2nt(system) 

    priors_vec = _list_priors(system)
    Bijector_invlinkvec = make_Bijector_invlinkvec(priors_vec)

    # Capture these variables in a let binding to improve performance
    ℓπ = let system=system, ln_prior_transformed=ln_prior_transformed, arr2nt=arr2nt#, ln_prior=ln_prior
        function (θ_t)
            # Transform back from the unconstrained support to constrained support for the likelihood function
            θ = Bijector_invlinkvec(θ_t)
            # θ = θ_t
            θ_res = arr2nt(θ)
            ll = ln_prior_transformed(θ) + ln_like(system, θ_res)
            # ll = ln_prior(θ) + ln_like(θ_res, system)
            return ll
        end
    end

    if isnothing(initial_parameters)
        verbosity >= 1 && @info "Guessing a good starting location by sampling from priors" initial_samples
        initial_θ = guess_starting_position(system,initial_samples)
        # Transform from constrained support to unconstrained support
        initial_θ_t = Bijectors.link.(priors_vec, initial_θ)
        # initial_θ_t = initial_θ
    else
        initial_θ = initial_parameters
        # Transform from constrained support to unconstrained support
        initial_θ_t = Bijectors.link.(priors_vec, initial_θ)
    end

    # Define a Hamiltonian system
    metric = DenseEuclideanMetric(D)
    hamiltonian = Hamiltonian(metric, ℓπ, autodiff)

    if !isnothing(step_size)
        initial_ϵ = step_size
    else
        initial_ϵ = find_good_stepsize(hamiltonian, initial_θ_t)
        verbosity >= 1 && @info "Found initial stepsize" initial_ϵ
    end


    integrator = Leapfrog(initial_ϵ)
    # integrator = TemperedLeapfrog(initial_ϵ, 1.05)


    mma = MassMatrixAdaptor(metric)
    if isnothing(step_size)
        verbosity >= 1 && @info "Adapting step size and mass matrix"
        ssa = StepSizeAdaptor(target_accept, integrator)
        adaptor = StanHMCAdaptor(mma, ssa) 
    else
        verbosity >= 1 && @info "Adapting adapt mass matrix only" step_size
        adaptor = MassMatrixAdaptor(metric)
    end

    model = AdvancedHMC.DifferentiableDensityModel(ℓπ, autodiff)

    # κ = NUTS{MultinomialTS,GeneralisedNoUTurn}(integrator, max_depth=tree_depth) 
    # κ = NUTS{SliceTS, StrictGeneralisedNoUTurn}(integrator, max_depth=tree_depth) 
    

    # Had some good results with this one:
    # κ = NUTS{MultinomialTS, StrictGeneralisedNoUTurn}(integrator, max_depth=tree_depth) 

    κ = NUTS(integrator, max_depth=tree_depth) 
    sampler = AdvancedHMC.HMCSampler(κ, metric, adaptor)


    start_time = fill(time(), num_chains)

    # Neat: it's possible to return a live iterator
    # We could use this to build e.g. live plotting while the code is running
    # once the analysis code is ported to Makie.
    # return  AbstractMCMC.steps(
    #     rng,
    #     model,
    #     sampler,
    #     nadapts = adaptation,
    #     init_params = initial_θ_t,
    #     discard_initial = adaptation,
    #     progress=progress,
    #     verbose=false
    # )


    last_output_time = Ref(time())
    function callback(rng, model, sampler, transition, state, iteration; kwargs...)
        if verbosity >= 1 && iteration == 1
            @info "Adaptation complete."

            # Show adapted step size and mass matrix
            if verbosity >= 3
                adapted_ss = AdvancedHMC.getϵ(adaptor)
                println("Adapated stepsize ϵ=", adapted_ss)
                adapted_mm = AdvancedHMC.getM⁻¹(adaptor)
                print("Adapted mass matrix M⁻¹ ")
                display(adapted_mm)
            end
            
            @info "Sampling..."
            verbosity >= 2 && println("Progress legend: divergence iter(thread) td=tree-depth ℓπ=log-posterior-density ")
        end
        if verbosity < 2 || last_output_time[] + 2 > time()
            return
        end
        # Give different messages if the log-density is non-finite,
        # or if there was a divergent transition.
        if !isfinite(transition.z.ℓπ)
            # TODO: this never runs since any non-finite proposal is rejected during sampling.
            note = "∞" 
        elseif transition.stat.numerical_error
            note = "X"
        else
            note = " "
        end
        if transition.z.ℓπ isa AdvancedHMC.DualValue
            ℓπ = transition.z.ℓπ.value
        else
            ℓπ = transition.z.ℓπ
        end

        θ_message = ""
        if verbosity >= 3
            θ = Bijector_invlinkvec(transition.z.θ)
            θ_res = arr2nt(θ)
            # Fill the remaining width of the terminal with info
            max_width = displaysize(stdout)[2]-34
            θ_str = string(θ_res)
            θ_str_trunc = θ_str[begin:prevind(θ_str, min(end,max_width))]
            θ_message = "θ="*θ_str_trunc*"..."
        end
        
        @printf("%1s%6d(%2d) td=%2d ℓπ=%6.0f. %s\n", note, iteration, Threads.threadid(), transition.stat.tree_depth, ℓπ, θ_message)
    
        # Support for live plotting orbits as we go.
        # This code works but I found it slows down a lot as we go. Maybe it would
        # work better with Makie.
        # for p_i in keys(system.planets)
        #     kep_elements = construct_elements(θ_res, θ_res.planets[p_i])
        #     color = if transition.stat.numerical_error
        #         :red
        #     elseif iteration <= adaptation
        #         :blue
        #     else
        #         :black
        #     end
        #     Main.plot!(kep_elements,color=color, label="")
        # end
        # display(Main.Plots.current())

        last_output_time[] = time()
        return
    end

    mc_samples_all_chains = sample(
        rng,
        model,
        sampler,
        ensemble,
        iterations,
        num_chains;
        nadapts = adaptation,
        thinning,
        init_params = initial_θ_t,
        discard_initial,
        progress=verbosity >= 1,
        callback
    )
    stop_time = fill(time(), num_chains)
    
    verbosity >= 1 && @info "Sampling compete. Building chains."
    # Go through each chain and repackage results
    chains = MCMCChains.Chains[]
    logposts = Vector{Float64}[]
    for (i,mc_samples) in enumerate(mc_samples_all_chains)
        stat = map(s->s.stat, mc_samples)
        logpost = map(s->s.z.ℓπ.value, mc_samples)
     
        mean_accept = mean(getproperty.(stat, :acceptance_rate))
        num_err_frac = mean(getproperty.(stat, :numerical_error))
        mean_tree_depth = mean(getproperty.(stat, :tree_depth))
        max_tree_depth_frac = mean(getproperty.(stat, :tree_depth) .== tree_depth)
    
        verbosity >= 1 && println("""
        Sampling report for chain $i:
        mean_accept =         $mean_accept
        num_err_frac =        $num_err_frac
        mean_tree_depth =     $mean_tree_depth
        max_tree_depth_frac = $max_tree_depth_frac\
        """)

        # Report some warnings if sampling did not work well
        if num_err_frac == 1.0
            @error "Numerical errors encountered in ALL iterations. Check model and priors."
        elseif num_err_frac > 0.1
            @warn "Numerical errors encountered in more than 10% of iterations" num_err_frac
        end
        if max_tree_depth_frac > 0.1
            @warn "Maximum tree depth hit in more than 10% of iterations (reduced efficiency)" max_tree_depth_frac
        end

        logpost = map(s->s.z.ℓπ.value, mc_samples)
    
        # Transform samples back to constrained support
        samples = map(mc_samples) do s
            θ_t = s.z.θ
            θ = Bijectors.invlink.(priors_vec, θ_t)
            return θ
        end
        chain_res = arr2nt.(samples)
        push!(chains, DirectDetections.result2mcmcchain(system, chain_res))
        push!(logposts, logpost)
    end

    # Concatenate the independent chains now that we have remapped / resolved the variables.
    mcmcchains = AbstractMCMC.chainscat(chains...)

    # Concatenate the log posteriors and make them the same shape as the chains (N_iters,N_vars,N_chains)
    logposts_mat = reduce(hcat, logposts)
    mcmcchains_with_info = MCMCChains.setinfo(
        mcmcchains,
        (;
            start_time,
            stop_time,
            model=system,
            logpost=logposts_mat,
            _restart=(;
                model,
                sampler,
                adaptor,
                state = last.(mc_samples_all_chains)
            )
        )
    )
    return mcmcchains_with_info
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
