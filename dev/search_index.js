var documenterSearchIndex = {"docs":
[{"location":"getting-started/#Getting-Started","page":"Getting Started","title":"Getting Started","text":"","category":"section"},{"location":"getting-started/","page":"Getting Started","title":"Getting Started","text":"The first step to using DirectDetections.jl is to install Julia. If you're used to Python, don't worry –- Julia is easy to install, and you won't need to code anything other than changing your input data.","category":"page"},{"location":"getting-started/#Installing-Julia","page":"Getting Started","title":"Installing Julia","text":"","category":"section"},{"location":"getting-started/","page":"Getting Started","title":"Getting Started","text":"Visit the julialang.org Downloads page, and select the latest stable version for your operating system. Currently, this is 1.6.2. Click the [help] links next to your operating system if you require more detailed instructions.","category":"page"},{"location":"getting-started/#Installing-DirectDetections","page":"Getting Started","title":"Installing DirectDetections","text":"","category":"section"},{"location":"getting-started/","page":"Getting Started","title":"Getting Started","text":"Normally, Julia packages are installed from the General registry. Since DirectDetections isn't quite ready for prime time, it requires one extra step to add an additional registry.","category":"page"},{"location":"getting-started/","page":"Getting Started","title":"Getting Started","text":"Start julia in a terminal by running julia\nType ] to enter package-mode (see Julia documentation for more details)\nType registry add https://github.com/sefffal/DirectRegistry\nType add DirectDetections Distributions","category":"page"},{"location":"getting-started/","page":"Getting Started","title":"Getting Started","text":"You will need the Distributions package added above so that you can specify priors for different parameters in your models.","category":"page"},{"location":"getting-started/","page":"Getting Started","title":"Getting Started","text":"If you would like to visualize your results, you can also install the Plots package:","category":"page"},{"location":"getting-started/","page":"Getting Started","title":"Getting Started","text":"Type add Plots","category":"page"},{"location":"getting-started/","page":"Getting Started","title":"Getting Started","text":"For loading images to sample, add the DirectImages package ","category":"page"},{"location":"getting-started/","page":"Getting Started","title":"Getting Started","text":"Type add DirectImages","category":"page"},{"location":"getting-started/","page":"Getting Started","title":"Getting Started","text":"Note: it's possible to use this package without DirectImages. This just simplifies the process of loading FITS files, and creating a centered OffsetArray with the star at index (0,0).","category":"page"},{"location":"getting-started/","page":"Getting Started","title":"Getting Started","text":"This will take a little while to download all the required packages and precompile for your system.","category":"page"},{"location":"getting-started/#Fitting-your-first-model","page":"Getting Started","title":"Fitting your first model","text":"","category":"section"},{"location":"getting-started/","page":"Getting Started","title":"Getting Started","text":"Start with the Fit Astrometry tutorial which shows how to model of one planet with some astrometry points.","category":"page"},{"location":"images/#fit-images","page":"Fit Images","title":"Fitting Images","text":"","category":"section"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"One of the key features of DirectDetections.jl is the ability to search for planets directly from images of the system. Sampling from images is much more computationally demanding than sampling from astrometry, but it allows for a few very powerful results:","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"You can search for a planet that is not well detected in a single image","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"By this, we mean you can feed in images of a system with no clear detections, and see if a planet is hiding in the noise based off of its Kepelerian motion.","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"Not detecting a planet in a given image can be almost as useful as a detection for constraining its orbit. ","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"If you have a clear detection in one epoch, but no detection in another, DirectDetections can use the image from the second epoch to rule out large swathes of possible orbits.","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"Sampling from images can be freely combined with any known astrometry points, as well as astrometric acceleration. See advanced models for more details.","category":"page"},{"location":"images/#Preparing-images","page":"Fit Images","title":"Preparing images","text":"","category":"section"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"The first step will be to load your images. For this, we will use our DirectImages.jl package; however, all that is really necessary is to load your image(s) into an array and adjust the axes so that the star is at index [0,0] (see OffsetArrays.jl if you want to do this yourself).","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"Start by loading your images:","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"using DirectImages\n\n# Load individual iamges\n# image1 = readfits(\"image1.fits\")\n# image2 = readfits(\"image2.fits\")\n\n# Or slices from a cube:\n# cube = readfits(\"cube1.fits\")\n# image1 = cube[:,:,1] \n\n# Or multi-extension FITS (this example)\nimages = readfits(\"image-examples-1.fits\",:)","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"You can preview the image using imshow2 from DirectImages:","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"# imshow2(image1, cmap=:magma) # for a single image\nimshow2([\n    images[1]\n    images[2]\n    images[3]\n    images[4]\n    images[5]\n], cmap=:magma, clims=(-1.0, 4.0))","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"(Image: images)","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"Your images should either be convolved with a gaussian of diameter one λ/D, or be matched filtered. This is so that DirectDetections the values of the pixels in the image approximate the photometry at that location. ","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"If you want to perform the convolution in Julia, see ImageFiltering.jl.","category":"page"},{"location":"images/#Build-the-model","page":"Fit Images","title":"Build the model","text":"","category":"section"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"Then, create a system with one or more planets. In this case, we will not provide any astrometry measurements for the planet, but they are supported with the same syntax as shown in the Fit Astrometry tutorial.","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"Start by specifying a planet:","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"@named X = DirectDetections.Planet(\n    Priors(\n        a = Normal(13, 3),\n        e = TruncatedNormal(0.2, 0.2, 0, 1.0),\n        τ = Normal(0.5, 1),\n        ω = Normal(0.1, deg2rad(30.)),\n        i = Normal(0.6, deg2rad(10.)),\n        Ω = Normal(0.0, deg2rad(30.)),\n        GPI_H = Normal(3.8, 0.5)\n    ),\n)","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"Note how we also provided a prior on the photometry called GPI_H. We can put any name we want here, as long as it's used consistently throughput the model specification.","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"See Fit Astrometry for a description of the different orbital parameters, and conventions used.","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"Now, we create a table of images that will be passed to the System:","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"system_images = DirectDetections.Images(\n    (band=:GPI_H, image=centered(images[1]), platescale=10.0, epoch=1238.6),\n    (band=:GPI_H, image=centered(images[2]), platescale=10.0, epoch=1584.7),\n    (band=:GPI_H, image=centered(images[3]), platescale=10.0, epoch=3220.0),\n    (band=:GPI_H, image=centered(images[4]), platescale=10.0, epoch=7495.9),\n    (band=:GPI_H, image=centered(images[5]), platescale=10.0, epoch=7610.4),\n)","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"Provide one entry for each image you want to sample from. Ensure that each image has been re-centered so that index [0,0] is the position of the star. Areas of the image where there is no data should be filled with NaN and will not contribute to the likelihood of your model. platescale should be the pixel scale of your images, in milliarseconds / pixel. epoch should be the Modified Julian Day (MJD) that your image was taken. You can use the mjd(\"2021-09-09\") function to calcualte this for you. band should be a symbol that matches the name you supplied when you created the Planet.","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"By default, the contrast of the images is calculated automatically, but you can supply your own contrast curve as well by also passing contrast=contrast_interp(centered(my_image)).","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"You can freely mix and match images from different instruments as long as you specify the correct platescale.  You can also provide images from multiple bands and they will be sampled independently. If you wish to tie them together, see Connecting Mass with Photometry.","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"Finally, create the system and pass in your table of images.","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"@named HD82134 = System(\n    Priors(\n        μ = Normal(2.0, 0.1),\n        plx =Normal(45., 0.02),\n    ),\n    system_images,\n    X,\n)","category":"page"},{"location":"images/#Sampling","page":"Fit Images","title":"Sampling","text":"","category":"section"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"By default, the sampler will lower the target acceptance ratio when sampling from images. This allows the sampler more freedom to explore the \"bumpy\" posterior of the images.","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"Start the NUTS sampler as usual:","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"chains, stats = DirectDetections.hmc(\n    HD82134;\n    burnin=8_000,\n    numwalkers=1,\n    numsamples_perwalker=100_000,\n);","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"Sampling directly from images is somewhat slower than from astrometry. This example takes roughly 7 minutes on my laptop.","category":"page"},{"location":"images/#Diagnostics","page":"Fit Images","title":"Diagnostics","text":"","category":"section"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"The first thing you should do with your results is check a few diagnostics to make sure the sampler converged as intended.","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"The acceptance rate should be somewhat lower than when fitting just astrometry, e.g. around the 0.6 target:","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"mean(getproperty.(stats[1], :acceptance_rate))","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"Check the mean tree depth (5-9):","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"mean(getproperty.(stats[1], :tree_depth))","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"Check the maximum tree depth reached (often 11-12, can be more):","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"maximum(getproperty.(stats[1], :tree_depth))","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"You can make a trace plot:","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"plot(\n    chains[1].planets[1].a,\n    xlabel=\"iteration\",\n    ylabel=\"semi-major axis (aU)\"\n)","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"And an auto-correlation plot:","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"using StatsBase\nplot(\n    autocor(chains[1].planets[1].e, 1:500),\n    xlabel=\"lag\",\n    ylabel=\"autocorrelation\",\n)","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"For this model, there is somewhat higher correlation between samples. Some thinning to remove this correlation is recommended. (Image: autocorrelation plot)","category":"page"},{"location":"images/#Analysis","page":"Fit Images","title":"Analysis","text":"","category":"section"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"You can plot the model as usual:","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"using Plots\nplotmodel(chains[1], HD82134)","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"(Image: images)","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"In this case, the model is shown overtop a stack of the input images to help you visualize which peaks contributed to the fit. The images are stacked using the maximum function, so that bright spots from all images appear at once. The colour scale is inverted, so that the brightest peaks are shown in black.","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"You can also specify a lims=1000 parameter to set limits of the images to +/- 1000 mas, in this example.","category":"page"},{"location":"images/#Pair-Plot","page":"Fit Images","title":"Pair Plot","text":"","category":"section"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"We can show the relationships between variables on a pair plot (aka corner plot) using PairPlots.jl","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"using PairPlots\ntable = (;\n    a=chains[1].planets[1].a,\n    H=chains[1].planets[1].GPI_H,\n    e=chains[1].planets[1].e,\n    i=rad2deg.(chains[1].planets[1].i),\n    Ω=rad2deg.(chains[1].planets[1].Ω),\n    ω=rad2deg.(chains[1].planets[1].ω),\n    τ=(chains[1].planets[1].τ),\n)\nlabels=[\n    \"a\",\n    \"H\",\n    \"e\",\n    \"i\",\n    \"\\\\Omega\",\n    \"\\\\omega\",\n    \"\\\\tau\",\n]\nunits = [\n    \"(au)\",\n    \"(arb.)\",\n    \"\",\n    \"(\\\\degree)\",\n    \"(\\\\degree)\",\n    \"(\\\\degree)\",\n    \"\",\n]\ncorner(table, labels, units)","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"Note that this time, we also show the recovered photometry in the corner plot.","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"(Image: corner plot)","category":"page"},{"location":"images/#Assessing-Detections","page":"Fit Images","title":"Assessing Detections","text":"","category":"section"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"To assess a detection, we can treat all the orbital variables as nuisance parameters.  We start by plotting the marginal distribution of the flux parameter, GPI_H:","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"histogram(chains[1].planets[1].GPI_H, xlabel=\"GPI_H\", label=\"\")","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"(Image: corner plot)","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"We can calculate an analog of the traditional signal to noise ratio (SNR) using that same histogram:","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"flux = chains[1].planets[1].GPI_H\nsnr = mean(flux)/std(flux) # 13.35 in this example","category":"page"},{"location":"images/","page":"Fit Images","title":"Fit Images","text":"It might be better to consider a related measure, like the median flux over the interquartile distance. This will depend on your application.","category":"page"},{"location":"modelling/#fit-astrometry","page":"Fit Astrometry","title":"Fitting Astrometry","text":"","category":"section"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"Here is a worked example of a basic model. It contains a star with a single planet, and several astrometry points.","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"The full code is available on GitHub","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"Start by loading the DirectDetections and Plots packages:","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"using DirectDetections, Distributions, Plots","category":"page"},{"location":"modelling/#Creating-a-planet","page":"Fit Astrometry","title":"Creating a planet","text":"","category":"section"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"Create our first planet. Let's name it planet X.","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"@named X = Planet(\n    Priors(\n        a = Normal(1, 0.5),\n        e = TruncatedNormal(0.0, 0.2, 0, 1.0),\n        τ = Normal(0.5, 1),\n        ω = Normal(deg2rad(250.), deg2rad(80.)),\n        i = Normal(deg2rad(20.), deg2rad(10.)),\n        Ω = Normal(deg2rad(200.), deg2rad(30.)),\n    ),\n    Astrometry(\n        (epoch=5000.,  ra=-364., dec=-1169., σ_ra=70., σ_dec=30.),\n        (epoch=5014.,  ra=-493., dec=-1104., σ_ra=70., σ_dec=30.),\n        (epoch=5072.,  ra=-899., dec=-629., σ_ra=10., σ_dec=50.),\n    )\n)","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"There's a lot going on here, so let's break it down.","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"The Priors block accepts the priors that you would like for the orbital parameters of this planet. Priors can be any univariate distribution from the Distributions.jl package. You will want to always specify the following parameters:","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"a: Semi-major axis, astronomical units (AU)\ni: Inclination, radius\ne: Eccentricity in the range [0, 1)\nτ: Epoch of periastron passage, in fraction of orbit [0,1] (periodic outside these bounds)\nω: Argument of periastron, radius\nΩ: Longitude of the ascending node, radians.","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"The parameter τ represents the epoch of periastron passage as a fraction of the planet's orbit between 0 and 1. This follows the same convention as Orbitize! and you can read more about their choice in ther FAQ.","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"The parameters can be specified in any order.","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"The Astrometry block is optional. This is where you can list the position of a planet at different epochs if it known. epoch is a modified Julian date that the observation was taken. the ra, dec, σ_ra, and σ_dec parameters are the position of the planet at that epoch, relative to the star. All values in milliarcseconds (mas).","category":"page"},{"location":"modelling/#Creating-a-system","page":"Fit Astrometry","title":"Creating a system","text":"","category":"section"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"A system represents a host star with one or more planets. Properties of the whole system are specified here, like parallax distance and mass of the star. This is also where you will supply data like images and astrometric acceleration in later tutorials, since those don't belong to any planet in particular.","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"@named HD82134 = System(\n    Priors(\n        μ = Normal(1.0, 0.01),\n        plx =Normal(1000.2, 0.02),\n    ),  \n    X,\n)","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"The Priors block works just like it does for planets. Here, the two parameters you must provide are:","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"μ: Gravitational parameter of the central body, expressed in units of Solar mass.\nplx: Distance to the system expressed in milliarcseconds of parallax.","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"After that, just list any planets that you want orbiting the star. Here, we pass planet X.","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"You can name the system and planets whatever you like. NB: the @named convenience macro just passes in the name as a keyword argument, e.g. name=:HD82134. This makes sure that the variable name matches what gets displayed in the package output, and saved a few keystrokes. (taken from ModellingToolkit.jl)","category":"page"},{"location":"modelling/#Sampling","page":"Fit Astrometry","title":"Sampling","text":"","category":"section"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"Great! Now we are ready to draw samples from the posterior.","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"Start sampling:","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"chains, stats = DirectDetections.hmc(\n    HD82134;\n    burnin=3_000,\n    numwalkers=1,\n    numsamples_perwalker=100_000\n);","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"You will get an output that looks something like with a progress bar that updates every second or so:","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"┌ Info: Guessing a good starting location by sampling from priors\n└   N = 100000\n┌ Info: Found good location\n│   mapv = -20.324754631163707\n│   a =\n│    1-element Vector{Float64}:\n└     0.8654035807041643\nSampling100%|███████████████████████████████| Time: 0:03:43\n  iterations:                    100000\n  n_steps:                       127\n  is_accept:                     true\n  acceptance_rate:               0.7433785597405826\n  log_density:                   -22.227228640579845\n  hamiltonian_energy:            28.28412166672831\n  hamiltonian_energy_error:      0.4320257855228391\n  max_hamiltonian_energy_error:  0.864362638326071\n  tree_depth:                    7\n  numerical_error:               false\n  step_size:                     0.016545736995705284\n  nom_step_size:                 0.016545736995705284\n  is_adapt:                      false\n  mass_matrix:                   DenseEuclideanMetric(diag=[0.00010561557446916532, 0. ...])","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"The sampler will begin by drawing orbits randomly from the priors (100,000 by default). It will then pick the orbit with the highest posterior density as a starting point for HMC adaptation. This recipe is a good way to find a point somewhat close to the typical set. Starting at the global maximum on the other hand, has at times not led to good sampling.","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"For a basic model like this, sampling should take less than a minute on a typical laptop.","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"A few things to watch out for: check that you aren't getting many (any, really) numerical_error=true. This likely indicates that the priors are too restrictive, and the sampler keeps taking steps outside of their valid range. It could also indicate a problem with DirectDetections, e.g. if the sampler is picking negative eccentricities. You may see some warnings during initial step-size adaptation. These are probably nothing to worry about if sampling proceeds normally afterwards.","category":"page"},{"location":"modelling/#Diagnostics","page":"Fit Astrometry","title":"Diagnostics","text":"","category":"section"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"The first thing you should do with your results is check a few diagnostics to make sure the sampler converged as intended.","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"You can check that the acceptance rate was reasonably high (0.4-0.95):","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"mean(getproperty.(stats[1], :acceptance_rate))","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"Check the mean tree depth (5-9):","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"mean(getproperty.(stats[1], :tree_depth))","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"Lower than this and the sampler is taking steps that are too large and encountering a U-turn very quicky. Much larger than 10 and it might be being too conservative. The default maximum tree depth is 16. It should not average anything close to this value, but occasional high values are okay.","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"Check the maximum tree depth reached (often 11-12, can be more):","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"maximum(getproperty.(stats[1], :tree_depth))","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"You can make a trace plot:","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"plot(\n    chains[1].planets[1].a,\n    xlabel=\"iteration\",\n    ylabel=\"semi-major axis (aU)\"\n)","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"(Image: trace plot)","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"And an auto-correlation plot:","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"using StatsBase\nplot(\n    autocor(chains[1].planets[1].e, 1:500),\n    xlabel=\"lag\",\n    ylabel=\"autocorrelation\",\n)","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"This plot shows that these samples are not correlated after only above 5 steps. No thinning is necessary. (Image: autocorrelation plot)","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"It's recommened that you run multiple chains for more steps to verify the convergance of your final results.","category":"page"},{"location":"modelling/#Analysis","page":"Fit Astrometry","title":"Analysis","text":"","category":"section"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"As a first pass, let's plot a sample of orbits drawn from the posterior.","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"using Plots\nplotmodel(chains[1], HD82134)","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"This function draws orbits from the posterior and displays them in a plot. Any astrometry points are overplotted. If other data like astrometric acceleration is provided, additional panels will appear. (Image: model plot)","category":"page"},{"location":"modelling/#Pair-Plot","page":"Fit Astrometry","title":"Pair Plot","text":"","category":"section"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"A very useful visualization of our results is a pair-plot, or corner plot. We can use our PairPlots.jl package for this purpose:","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"using Plots, PairPlots\n\n\ntable = (;\n    a=chains[1].planets[1].a,\n    e=chains[1].planets[1].e,\n    i=rad2deg.(chains[1].planets[1].i),\n    Ω=rad2deg.(chains[1].planets[1].Ω),\n    ω=rad2deg.(chains[1].planets[1].ω),\n    τ=(chains[1].planets[1].τ),\n);\nlabels=[\"a\", \"e\", \"i\", \"\\\\Omega\", \"\\\\omega\", \"\\\\tau\"]\nunits = [\"(au)\", \"\", \"(\\\\degree)\", \"(\\\\degree)\", \"(\\\\degree)\", \"\"]\n\ncorner(table, labels, units, plotscatter=false)","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"You can read more about the syntax for creating pair plots in the PairPlots.jl documentation page. (Image: corner plot) In this case, the sampler was able to resolve the complicated degeneracies between eccentricity, the longitude of the ascending node, and argument of periapsis.","category":"page"},{"location":"modelling/#Notes-on-Hamiltonian-Monte-Carlo","page":"Fit Astrometry","title":"Notes on Hamiltonian Monte Carlo","text":"","category":"section"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"Traditional Affine Invariant MCMC is supported (similar to the python emcee package), but it is recommended that you use Hamiltonian Monte Carlo. This sampling method makes use of derivative information, and is much more efficient. This package by default uses the No U-Turn sampler, as implemented in AdvancedHMC.jl.","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"Derviatives for a complex model are usualy tedious to code, but DirectDetections uses ForwardDiff.jl to generate them automatically.","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"When using HMC, only a few chains are necessary. This is in contrast to Affine Invariant MCMC based packages where hundreds or thousands of walkers are required. One chain should be enough to cover the whole posterior, but you can run a few different chains to make sure each has converged to the same distribution.","category":"page"},{"location":"modelling/","page":"Fit Astrometry","title":"Fit Astrometry","text":"Similarily, many fewer samples are required. This is because unlike Affine Invariant MCMC, HMC produces samples that are much less correlated after each step (i.e. the autocorrelation time is much shorter).","category":"page"},{"location":"#DirectDetections.jl","page":"Home","title":"DirectDetections.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Welcome to the documentation page for DirectDetections.jl.  This page includes tutorial and an API reference for using this package.","category":"page"},{"location":"","page":"Home","title":"Home","text":"DirectDetections is a Julia package for performing Bayesian inference against direct images of exoplanets, exoplanet astrometry, astrometric acceleration of the host star, and radial velocity (future).","category":"page"},{"location":"","page":"Home","title":"Home","text":"You build a model of the system using the functions described below, list any data you might have, and start the sampler. The package also contains analysis and visualization tools for understanding your results.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Supported data:","category":"page"},{"location":"","page":"Home","title":"Home","text":"sample directly from images\nexoplanet astrometry \nstellar astrometric acceleration","category":"page"},{"location":"","page":"Home","title":"Home","text":"Any and all combinations also work together.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modelling features:","category":"page"},{"location":"","page":"Home","title":"Home","text":"multiple planets (one or more)\nco-planar, and non-coplanar systems\nhierarchical models\nlink mass to photometry via an atmosphere model","category":"page"},{"location":"","page":"Home","title":"Home","text":"The package supports only bound, 2-body Keplerian orbits. Support for hyperbolic orbits and multi-body physics are not currently planned.","category":"page"},{"location":"#Table-of-Contents","page":"Home","title":"Table of Contents","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"pma/#fit-pma","page":"Fit Astrometric Acceleration","title":"Fit Astrometric Acceleration","text":"","category":"section"},{"location":"mass-photometry/#mass-photometry","page":"Connecting Mass with Photometry","title":"Connecting Mass with Photometry","text":"","category":"section"}]
}
