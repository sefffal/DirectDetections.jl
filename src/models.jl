

function ln_like(pma::ProperMotionAnom, θ_system, elements)
    ll = 0.0

    # How many points over Δt should we average the proper motion at each
    # epoch? This is because the PM is not an instantaneous measurement.
    N_ave = 5
    
    for i in eachindex(pma.table.ra_epoch, pma.table.dec_epoch)
        pm_ra_star = 0.0
        pm_dec_star = 0.0
        
        # The model can support multiple planets
        # for key in keys(θ_system.planets)
        for j in eachindex(elements)
            θ_planet = θ_system.planets[j]
            orbit = elements[j]

            if θ_planet.mass < 0
                return -Inf
            end

            # Average multiple observations over a timescale +- dt
            # to approximate what HIPPARCOS and GAIA would have measured.
            for δt = range(-pma.table.dt[i]/2, pma.table.dt[i]/2, N_ave)

                # RA and dec epochs are usually slightly different
                # Note the unit conversion here from jupiter masses to solar masses to 
                # make it the same unit as the stellar mass (element.mu)
                pm_ra_star += pmra(orbit, pma.table.ra_epoch[i]+δt, θ_planet.mass*mjup2msol)
                pm_dec_star += pmdec(orbit, pma.table.dec_epoch[i]+δt, θ_planet.mass*mjup2msol)
            end

        end
        
        pm_ra_star/=N_ave
        pm_dec_star/=N_ave

        residx = pm_ra_star + θ_system.pmra - pma.table.pm_ra[i]
        residy = pm_dec_star + θ_system.pmdec - pma.table.pm_dec[i]
        σ²x = pma.table.σ_pm_ra[i]^2
        σ²y = pma.table.σ_pm_dec[i]^2
        χ²x = -0.5residx^2 / σ²x - log(sqrt(2π * σ²x))
        χ²y = -0.5residy^2 / σ²y - log(sqrt(2π * σ²y))

        ll += χ²x + χ²y
    end

    return ll
end


function ln_like(pma::ProperMotionAnomHG, θ_system, elements)
    ll = 0.0

    # How many points over Δt should we average the proper motion at each
    # epoch? This is because the PM is not an instantaneous measurement.
    N_ave = 5

    # Look at the position of the star around both epochs to calculate 
    # a delta-position proper motion
    ra_star_1 = 0.0
    dec_star_1 = 0.0
    # The model can support multiple planets
    for i in eachindex(elements)
        θ_planet = θ_system.planets[i]
        orbit = elements[i]
        if θ_planet.mass < 0
            return -Inf
        end
        # Average multiple observations over a timescale +- dt
        # to approximate what HIPPARCOS and GAIA would have measured.
        for δt = range(-pma.table.dt_1[1]/2, pma.table.dt_1[1]/2, N_ave)
            # RA and dec epochs are usually slightly different
            # Note the unit conversion here from jupiter masses to solar masses to 
            # make it the same unit as the stellar mass (element.mu)
            ra_star_1 += -raoff(orbit, pma.table.ra_epoch_1[1]+δt) * θ_planet.mass*mjup2msol/orbit.M
            dec_star_1 += -decoff(orbit, pma.table.dec_epoch_1[1]+δt) * θ_planet.mass*mjup2msol/orbit.M
        end
    end
    ra_star_1/=N_ave
    dec_star_1/=N_ave

    ra_star_2 = 0.0
    dec_star_2 = 0.0
    # The model can support multiple planets
    for i in eachindex(elements)
        θ_planet = θ_system.planets[i]
        orbit = elements[i]
        if θ_planet.mass < 0
            return -Inf
        end
        # Average multiple observations over a timescale +- dt
        # to approximate what HIPPARCOS and GAIA would have measured.
        for δt = range(-pma.table.dt_2[1]/2, pma.table.dt_2[1]/2, N_ave)
            # RA and dec epochs are usually slightly different
            # Note the unit conversion here from jupiter masses to solar masses to 
            # make it the same unit as the stellar mass (element.mu)
            ra_star_2 += -raoff(orbit, pma.table.ra_epoch_2[1]+δt) * θ_planet.mass*mjup2msol/orbit.M
            dec_star_2 += -decoff(orbit, pma.table.dec_epoch_2[1]+δt) * θ_planet.mass*mjup2msol/orbit.M
        end
    end
    ra_star_2/=N_ave
    dec_star_2/=N_ave

    pm_ra_star = ra_star_2 - ra_star_1
    pm_dec_star = dec_star_2 - dec_star_1

    residx = pm_ra_star + θ_system.pmra - pma.table.pm_ra[1]
    residy = pm_dec_star + θ_system.pmdec - pma.table.pm_dec[1]
    σ²x = pma.table.σ_pm_ra[1]^2
    σ²y = pma.table.σ_pm_dec[1]^2
    χ²x = -0.5residx^2 / σ²x - log(sqrt(2π * σ²x))
    χ²y = -0.5residy^2 / σ²y - log(sqrt(2π * σ²y))

    ll += χ²x + χ²y

    return ll
end

# TODO: image modelling for multi planet systems do not consider how "removing" one planet
# might increase the contrast of another.
# function ln_like_images(θ_system, system)
#     ll = 0.0
#     for key in keys(θ_system.planets)
#         θ_planet = θ_system.planets[key]
#         elements = construct_elements(θ_system, θ_planet)

#         if (elements.a <= 0 ||
#             elements.e < 0 ||
#             elements.plx < 0 ||
#             elements.μ <= 0)
#             ll += NaN
#             continue
#         end


#         ll += ln_like_images_element(elements, θ_planet, system)
#     end

#     # # Connect the flux at each epoch to an overall flux in this band for this planet
#     # # fᵢ = θ_band.epochs
#     # # ll += -1/2 * sum(
#     # #     (fᵢ .- θ_band.f).^2
#     # # ) / (θ_band.σ_f² * mean(fᵢ)^2)

#     # And connect that flux to a modelled Teff and mass
#     # f_model = model_interpolator(θ_planet.Teff, θ_planet.mass)
#     # ll += -1/2 * (f_model - θ_band)^2 /  (θ_planet.σ_f_model² * f_model^2)

#     return ll
# end

# function ln_like(images::Images, elements::DirectOrbits.AbstractElements, θ_planet)
function ln_like(images::Images, θ_system, θ_planet)
    
    # Resolve the combination of system and planet parameters
    # as a KeplerianElements object. This pre-computes
    # some factors used in various calculations.
    elements = construct_elements(θ_system, θ_planet)

    imgtable = images.table
    T = eltype(θ_planet)
    ll = zero(T)
    for i in eachindex(imgtable.epoch)
       
        # Calculate position at this epoch
        o = orbitsolve(elements, imgtable.epoch[i])
        # x must be negated to go from sky coordinates (ra increasing to left) to image coordinates (ra increasing to right).
        x = -raoff(o)
        y = decoff(o)

        # Get the photometry in this image at that location
        # Note in the following equations, subscript x (ₓ) represents the current position (both x and y)
        f̃ₓ = lookup_coord(imgtable.image[i], (x, y), imgtable.platescale[i])

        # Find the uncertainty in that photometry value (i.e. the contrast)
        r = √(x^2 + y^2)
        σₓ = imgtable.contrast[i](r / imgtable.platescale[i])

        # When we get a position that falls outside of our available
        # data (e.g. under the coronagraph) we cannot say anything
        # about the likelihood. This is equivalent to σₓ→∞ or log likelihood 
        # of zero.
        if !isfinite(σₓ) || !isfinite(f̃ₓ)
            continue
        end

        band = imgtable.band[i]

        # Verify the user has specified a prior or model for this band.
        if !hasproperty(θ_planet, band)
            error("No photometry prior for the band $band was specified, and neither was mass.")
        end
        # TODO: verify this is type stable
        f_band = getproperty(θ_planet, band)
        # Direct imaging likelihood.
        # Notes: we are assuming that the different images fed in are not correlated.
        # The general multivariate Gaussian likleihood is exp(-1/2 (x⃗-μ⃗)ᵀ𝚺⁻¹(x⃗-μ⃗)) + √((2π)ᵏ|𝚺|)
        # Because the images are uncorrelated, 𝚺 is diagonal and we can separate the equation
        # into a a product of univariate Gaussian likelihoods or sum of log-likelihoods.
        # That term for each image is given below.

        # Ruffio et al 2017, eqn (31)
        # Mawet et al 2019, eqn (8)

        σₓ² = σₓ^2
        ll += -1 / (2σₓ²) * (f_band^2 - 2f_band * f̃ₓ) 
    end

    return ll
end

# Astrometry
function ln_like(astrom::Astrometry, θ_planet, elements)
    ll = 0.0
    for i in eachindex(astrom.table.epoch)
        o = orbitsolve(elements, astrom.table.epoch[i])
        # PA and Sep specified
        if haskey(astrom.table, :pa) && haskey(astrom.table, :ρ)
            ρ = projectedseparation(o)
            pa = posangle(o)
            resid1 = astrom.table.pa[i] - pa
            resid2 = astrom.table.ρ[i] - ρ
        # RA and DEC specifoied
        else
            x = raoff(o)
            y = decoff(o)
            resid1 = astrom.table.ra[i] - x
            resid2 = astrom.table.dec[i] - y
            σ²1 = astrom.table.σ_ra[i ]^2
            σ²2 = astrom.table.σ_dec[i]^2
        end
        σ²1 = astrom.table.σ_ra[i ]^2
        σ²2 = astrom.table.σ_dec[i]^2
        χ²1 = -(1/2)*resid1^2 / σ²1 - log(sqrt(2π * σ²1))
        χ²2 = -(1/2)*resid2^2 / σ²2 - log(sqrt(2π * σ²2))
        ll += χ²1 + χ²2
    end
    return ll
end

# Photometry
function ln_like(photometry::Photometry, θ_planet, elements=nothing)
    ll = 0.0
    for i in eachindex(photometry.table.band)
        band = photometry.table.band[i]
        phot_param = getproperty(θ_planet, band)
        phot_meas = photometry.table.phot[i]
        if !isfinite(phot_param)
            return -Inf
        end
        σ_phot = photometry.table.σ_phot[i]
        resid = phot_param - phot_meas
        σ² = σ_phot^2
        χ² = -(1/2)*resid^2 / σ² - log(sqrt(2π * σ²))
        ll += χ²
    end
    return ll
end

# Overall log likelihood of the system given the parameters θ_system
function ln_like(system::System, θ_system)
    # We box ll directly to avoid annoying Core.Box due to the map closure below.
    ll = Ref{typeof(first(θ_system))}(0.0)
    # Fail fast if we have a negative stellar mass.
    # Users should endeavour to use priors on e.g. stellar mass
    # that are strictly positive.
    if hasproperty(θ_system, :M) && θ_system.M <= 0
        return -Inf
    end

    # Go through each planet in the model and add its contribution
    # to the ln-likelihood.
    # for (θ_planet, planet) in zip(θ_system.planets, system.planets)
    # for i in eachindex(system.planets)
    elements = map(eachindex(system.planets)) do i
        planet = system.planets[i]
        θ_planet = θ_system.planets[i]

        # Like negative stellar mass, users should use priors with supports
        # that do not include these invalid values. But if we see them,
        # give zero likelihood right away instead of an inscrutable error
        # from some code expecting these invariants to hold.
        if (hasproperty(θ_planet, :a) && θ_planet.a <= 0) ||
            (hasproperty(θ_planet, :e) && !(0 <= θ_planet.e < 1))
            ll[] += -Inf
        end

        # Resolve the combination of system and planet parameters
        # as a KeplerianElements object. This pre-computes
        # some factors used in various calculations.
        kep_elements = construct_elements(θ_system, θ_planet)

        for obs in planet.observations
            ll[] += ln_like(obs, θ_planet, kep_elements)
        end

        return kep_elements
    end

    if !isfinite(ll[])
        return ll[]
    end

    # Loop through and add contribution of all observation types associated with this system as a whole
    for obs in system.observations
        ll[] += ln_like(obs, θ_system, elements)
    end



    return ll[]
end



    # Hierarchical parameters over multiple planets
    # if haskey(system.priors.priors, :σ_i²)
    #     # If the sampler wanders into negative variances, return early to prevent
    #     # taking square roots of negative values later on
    #     if θ.σ_i² < 0
    #         return -Inf
    #     end

    #     # hierarchical priors here
    #     sum_iᵢ = zero(θ.i)
    #     sum_iᵢθi² = zero(θ.i)
    #     for θ_planet in θ.planets
    #         sum_iᵢ += θ_planet.i
    #         sum_iᵢθi² += (θ_planet.i .- θ.i)^2
    #     end
    #     ll += -1/2 * sum_iᵢθi² / θ.σ_i²  - log(sqrt(2π * θ.σ_i²))
    # end
    # if haskey(system.priors.priors, :σ_Ω²)
    #     # If the sampler wanders into negative variances, return early to prevent
    #     # taking square roots of negative values later on
    #     if θ.σ_Ω² < 0
    #         return -Inf
    #     end

    #     # hierarchical priors here
    #     sum_Ωᵢ = zero(θ.Ω)
    #     sum_ΩᵢθΩ² = zero(θ.Ω)
    #     for θ_planet in θ.planets
    #         _, Ωᵢ, _  = get_ωΩτ(θ_system, θ_planet)
    #         sum_Ωᵢ += Ωᵢ
    #         sum_ΩᵢθΩ² += (Ωᵢ .- θ.Ω)^2
    #     end
    #     ll += -1/2 * sum_ΩᵢθΩ² / θ.σ_Ω²  - log(sqrt(2π * θ.σ_Ω²))
    # end






# This is a straight forward implementation that unfortunately is not type stable.
# This is because we are looping over a heterogeneous container
# function make_ln_prior(priors)
#     return function ln_prior(params)
#         lp = zero(first(params))
#         for i in eachindex(params)
#             pd = priors[i]
#             param = params[i]
#             lp += logpdf(pd, param)
#         end
#         return lp 
#     end
# end

function make_ln_prior(system::System)

    # This function uses meta-programming to unroll all the code at compile time.
    # This is a big performance win, since it avoids looping over all the different
    # types of distributions that might be specified as priors.
    # Otherwise we would have to loop through an abstract vector and do runtime dispatch!
    # This way all the code gets inlined into a single tight numberical function in most cases.

    i = 0
    prior_evaluations = Expr[]

    # System priors
    for prior_distribution in values(system.priors.priors)
        i += 1
        ex = :(
            lp += $logpdf($prior_distribution, arr[$i])
        )
        push!(prior_evaluations,ex)
    end

    # Planet priors
    for planet in system.planets
        # for prior_distribution in values(planet.priors.priors)
        for (key, prior_distribution) in zip(keys(planet.priors.priors), values(planet.priors.priors))
            i += 1
            # Work around for Beta distributions.
            # Outside of the range [0,1] logpdf returns -Inf.
            # This works fine, but AutoDiff outside this range causes a DomainError.
            if typeof(prior_distribution) <: Beta
                ex = :(
                    lp += 0 <= arr[$i] < 1 ? $logpdf($prior_distribution, arr[$i]) : -Inf
                )
            else
                ex = :(
                    lp += $logpdf($prior_distribution, arr[$i])
                )
            end
            push!(prior_evaluations,ex)
        end
    end

    # Here is the function we return.
    # It maps an array of parameters into our nested named tuple structure
    # Note: eval() would normally work fine here, but sometimes we can hit "world age problemms"
    # The RuntimeGeneratedFunctions package avoids these in all cases.
    return @RuntimeGeneratedFunction(:(function (arr)
        l = $i
        @boundscheck if length(arr) != l
            error("Expected exactly $l elements in array (got $(length(arr)))")
        end
        lp = zero(first(arr))
        # Add contributions from planet priors
        @inbounds begin
           $(prior_evaluations...) 
        end
        return lp
    end))
end

# Same as above, but assumes the input to the log prior was sampled
# using transformed distributions from Bijectors.jl
# Uses logpdf_with_trans() instead of logpdf to make the necessary corrections.
function make_ln_prior_transformed(system::System)

    i = 0
    prior_evaluations = Expr[]

    # System priors
    for prior_distribution in values(system.priors.priors)
        i += 1
        ex = :(
            lp += $logpdf_with_trans($prior_distribution, arr[$i], true)
        )
        push!(prior_evaluations,ex)
    end

    # Planet priors
    for planet in system.planets
        # for prior_distribution in values(planet.priors.priors)
        for (key, prior_distribution) in zip(keys(planet.priors.priors), values(planet.priors.priors))
            i += 1
            ex = :(
                lp += $logpdf_with_trans($prior_distribution, arr[$i], true)
            )
            push!(prior_evaluations,ex)
        end
    end

    # Here is the function we return.
    # It maps an array of parameters into our nested named tuple structure
    # Note: eval() would normally work fine here, but sometimes we can hit "world age problemms"
    # The RuntimeGeneratedFunctions package avoids these in all cases.
    return @RuntimeGeneratedFunction(:(function (arr)
        l = $i
        @boundscheck if length(arr) != l
            error("Expected exactly $l elements in array (got $(length(arr)))")
        end
        lp = zero(first(arr))
        # Add unrolled prior evaluations
        @inbounds begin
           $(prior_evaluations...) 
        end
        return lp
    end))
end


# # Replaces `θ = Bijectors.invlink.(priors_vec, θ_t)` with a type stable
# # unrolled version.
# function make_Bijector_invlinkvec(priors_vec)

#     i = 0
#     parameter_transformations = Expr[]

#     # System priors
#     for prior_distribution in priors_vec
#         i += 1
#         ex = :(
#             theta_out[$i] = $(Bijectors.invlink)($prior_distribution, arr[$i])
#         )
#         push!(parameter_transformations, ex)
#     end

#     # Here is the function we return.
#     # It maps an array of parameters into our nested named tuple structure
#     # Note: eval() would normally work fine here, but sometimes we can hit "world age problemms"
#     # The RuntimeGeneratedFunctions package avoids these in all cases.
#     return @RuntimeGeneratedFunction(:(function (arr)
#         l = $i
#         theta_out = @MVector zeros(eltype(arr), l)
#         # theta_out = zeros(eltype(arr), l)
#         @boundscheck if length(arr) != l
#             error("Expected exactly $l elements in array (got $(length(arr)))")
#         end
#         # Add unrolled parameter transformations to fill theta_out
#         @inbounds begin
#            $(parameter_transformations...) 
#         end
#         return theta_out
#     end))
# end


# Replaces `θ = Bijectors.invlink.(priors_vec, θ_t)` with a type stable
# unrolled version.
function make_Bijector_invlinkvec(priors_vec)

    i = 0
    parameter_transformations = Expr[]

    # System priors
    for prior_distribution in priors_vec
        i += 1
        ex = :(
            $(Bijectors.invlink)($prior_distribution, arr[$i])
        )
        push!(parameter_transformations, ex)
    end

    # Here is the function we return.
    # It maps an array of parameters into our nested named tuple structure
    # Note: eval() would normally work fine here, but sometimes we can hit "world age problemms"
    # The RuntimeGeneratedFunctions package avoids these in all cases.
    return @RuntimeGeneratedFunction(:(function (arr)
        l = $i
        # theta_out = zeros(eltype(arr), l)
        @boundscheck if length(arr) != l
            error("Expected exactly $l elements in array (got $(length(arr)))")
        end
        # Add unrolled parameter transformations to fill theta_out
        @inbounds begin
            # theta_out = SVector{l,eltype(arr)}(
            # theta_out = MVector{l,eltype(arr)}(
            theta_out = tuple(
                $(parameter_transformations...) 
            )
        end
        return theta_out
    end))
end


function ln_post(θ, system::System)
    return ln_prior(θ, system) + ln_like(θ, system)
end
