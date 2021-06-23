

function ln_like(θ, pma::ProperMotionAnom)
    ll = 0.0
    for i in eachindex(pma.ra_epoch, pma.dec_epoch)
        pm_ra_star = 0.0
        pm_dec_star = 0.0
        
        # The model can support multiple planets
        for θ_planet in θ.planets
            
            # TODO, we are creating these from scratch for each observation instead of sharing them
            elements = KeplerianElements((;
                θ.μ,
                θ.plx,
                θ_planet.i,
                θ_planet.Ω,
                θ_planet.ω,
                θ_planet.e,
                θ_planet.τ,
                θ_planet.a,
            ))

            # RA and dec epochs are usually slightly different
            pm_ra_star += propmotionanom(elements, pma.ra_epoch[i], elements.μ, θ_planet.mass)[1]
            pm_dec_star += propmotionanom(elements, pma.dec_epoch[i], elements.μ, θ_planet.mass)[2]
        end

        residx = pm_ra_star - pma.pm_ra[i]
        residy = pm_dec_star - pma.pm_dec[i]
        σ²x = pma.σ_pm_ra[i]^2
        σ²y = pma.σ_pm_dec[i]^2
        χ²x = -0.5residx^2 / σ²x - log(sqrt(2π * σ²x))
        χ²y = -0.5residy^2 / σ²y - log(sqrt(2π * σ²y))

        ll += χ²x + χ²y
    end

    return ll
end



function ln_like(θ, images::Images)
    ll = 0.0
    for i in eachindex(images.epoch), θ_planet in θ.planets
            
        # TODO, we are creating these from scratch for each observation instead of sharing them
        elements = KeplerianElements((;
            θ.μ,
            θ.plx,
            θ_planet.i,
            θ_planet.Ω,
            θ_planet.ω,
            θ_planet.e,
            θ_planet.τ,
            θ_planet.a,
        ))


        # Calculate position at this epoch
        ra, dec = kep2cart(elements, images.epoch[i])
        x = -ra
        y = dec

        # Get the photometry in this image at that location
        # Note in the following equations, subscript x (ₓ) represents the current position (both x and y)
        f̃ₓ = lookup_coord(images.image[i], (x, y), images.platescale[i])

        # Find the uncertainty in that photometry value (i.e. the contrast)
        r = √(x^2 + y^2)
        σₓ = images.contrast[i](r / images.platescale[i])

        # When we get a position that falls outside of our available
        # data (e.g. under the coronagraph) we cannot say anything
        # about the likelihood. This is equivalent to σₓ→∞ or log likelihood 
        # of zero.
        if !isfinite(σₓ) || !isfinite(f̃ₓ)
            continue
        end

        # Ruffio et al 2017, eqn 31
        # ll += -1/(2σₓ^2) * (θ_epoch_f^2 - 2θ_epoch_f*f̃ₓ)
        # ll += -1/(2σₓ^2) * (θ_band^2 - 2θ_band*f̃ₓ)

        band = images.band[i]
        f_band = getproperty(θ_planet, band)

        σₓ² = σₓ^2
        ll += -1 / (2σₓ²) * (f_band^2 - 2f_band * f̃ₓ) - log(sqrt(2π * σₓ²))
    end

    # # Connect the flux at each epoch to an overall flux in this band for this planet
    # # fᵢ = θ_band.epochs
    # # ll += -1/2 * sum(
    # #     (fᵢ .- θ_band.f).^2
    # # ) / (θ_band.σ_f² * mean(fᵢ)^2)

    # And connect that flux to a modelled Teff and mass
    # f_model = model_interpolator(θ_planet.Teff, θ_planet.mass)
    # ll += -1/2 * (f_model - θ_band)^2 /  (θ_planet.σ_f_model² * f_model^2)

    return ll
end

# Astrometry
function ln_like(θ, planets, ::Type{Planet})
    ll = 0.0
    
    for (planet, θ_planet) in zip(planets, θ.planets)
        if !isnothing(planet.astrometry)
            ll += ln_like_one_planet_astrom(θ, planet, θ_planet)
        end
    end
    return ll
end


function ln_like_one_planet_astrom(θ, planet, θ_planet)
    ll = 0.0
    
    # TODO, we are creating these from scratch for each observation instead of sharing them
    elements = KeplerianElements((;
        θ.μ,
        θ.plx,
        θ_planet.i,
        θ_planet.Ω,
        θ_planet.ω,
        θ_planet.e,
        θ_planet.τ,
        θ_planet.a,
    ))
    
    astrom = planet.astrometry
    for i in eachindex(astrom.epoch)

        x, y = kep2cart(elements, astrom.epoch[i])
        residx = astrom.ra[i] - x
        residy = astrom.dec[i] - y
        σ²x = astrom.σ_ra[i]^2
        σ²y = astrom.σ_dec[i]^2
        χ²x = -0.5residx^2 / σ²x - log(sqrt(2π * σ²x))
        χ²y = -0.5residy^2 / σ²y - log(sqrt(2π * σ²y))
        ll += χ²x + χ²y
    end

    return ll
end


function ln_like(θ, system::System)
    ll = 0.0
    if !isnothing(system.images)
        ll += ln_like(θ, system.images)
    end
    if !isnothing(system.propermotionanom)
        ll += ln_like(θ, system.propermotionanom)
    end
    ll += ln_like(θ, system.planets, Planet) # astrometry

    if haskey(system.priors.priors, :i)
        # hierarchical priors here
        sum_iᵢ = zero(θ.i)
        sum_iᵢθi² = zero(θ.i)
        for θ_planet in θ.planets
            sum_iᵢ += θ_planet.i
            sum_iᵢθi² += (θ_planet.i .- θ.i)^2
        end
        ll += -1/2 * sum_iᵢθi² / θ.σ_i² # TODO: missing sqrt pi factor?
        # ll += -1/2 * sum(
        #     (iᵢ .- θ.i).^2
        # ) / (θ.σ_i² * mean(iᵢ)^2)
    end

    if haskey(system.priors.priors, :Ω)
        # hierarchical priors here
        sum_Ωᵢ = zero(θ.Ω)
        sum_ΩᵢθΩ² = zero(θ.Ω)
        for θ_planet in θ.planets
            sum_Ωᵢ += θ_planet.Ω
            sum_ΩᵢθΩ² += (θ_planet.Ω .- θ.Ω)^2
        end
        ll += -1/2 * sum_ΩᵢθΩ² / θ.σ_Ω² # TODO: missing sqrt pi factor?
        # ll += -1/2 * sum(
        #     (Ωᵢ .- θ.Ω).^2
        # ) / (θ.σ_Ω² * mean(Ωᵢ)^2)
    end
    

    return ll
end






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

# This implementation is ~5x faster for the same result.
# It uses metaprogramming to unroll the loop over the different
# prior types. Note that this also ensures the priors can't be modified
# after building the ln_prior function.
function make_ln_prior(θ)

    body = Expr[]
    # for i in eachindex(θ)
    #     pd = θ[i]
    #     ex = :(lp += logpdf($pd, params[$i]))
    #     push!(body, ex)
    # end

    # Vrsion using symbolic keys more robust against reordering the parameters for some reason
    for i in eachindex(θ)
        pd = θ[i]
        key = keys(θ)[i]
        ex = :(lp += logpdf($pd, params.$key))
        push!(body, ex)
    end

    ex = :(function (params)
        lp = zero(first(params))
        $(body...)
        return lp
    end)

    ln_prior = @RuntimeGeneratedFunction(ex)
    return ln_prior
end


function make_ln_prior(θ, system::System)
    body = Expr[]
    for (planet, θ_planet) in zip(system.planets, θ.planets)
        ex = :(lp += $planet.priors.ln_prior($θ_planet))
        push!(body, ex)
    end
    ex = :(function (params, system)
        lp = system.priors.ln_prior(params)
        $(body...)
        return lp
    end)
    ln_prior = @RuntimeGeneratedFunction(ex)
    return ln_prior
end



function ln_prior(θ, system::System)
    lp = 0.0
    lp += system.priors.ln_prior(θ) # TODO
    for (planet, θ_planet) in zip(system.planets, θ.planets)
        lp += planet.priors.ln_prior(θ_planet)
    end
    return lp
end

function ln_post(θ, system::System)
    return ln_prior(θ, system) + ln_like(θ, system)
end

