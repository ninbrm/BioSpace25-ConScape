nothing
# add ConScape#demo
using ConScape, SparseArrays, LinearAlgebra
using Rasters, ArchGDAL
using ConScape.LinearSolve
using CairoMakie


# Step 1: Data import and raster stack
datadir = joinpath(dirname(pathof(ConScape)), "..", "data")
readdir(datadir)
_tempdir = mkdir(tempname())

landscape = "200"
# The way the ascii is read in is reversed and rotated from what GDAL does
qualities = reverse(rotr90(replace_missing(Raster(joinpath(datadir, "hab_qual_$landscape.asc")), NaN)); dims=X)
Makie.plot(qualities, colormap=cgrad([:lightgrey, :green]))
affinities = reverse(rotr90(replace_missing(Raster(joinpath(datadir, "mov_prob_$landscape.asc")), NaN)); dims=X)
Makie.plot(qualities, colormap=cgrad(:acton))

qualities[(affinities .> 0) .& isnan.(qualities)] .= 1e-20
rast = RasterStack((; affinities, qualities, target_qualities=qualities))
Rasters.rplot(rast)

solver = ConScape.MatrixSolver()

# show effect of theta
graph_measures = (; betq=ConScape.BetweennessQweighted())
distance_transformation = (nodist=nothing)

qualities[:,:] .= 0
#qualities[60,70] = 1
#qualities[50, 105] = 1
qualities[250, 500] = 1
qualities[350, 400] = 1
Makie.plot(Array(qualities), colormap=cgrad([:lightgrey, :green]))
rast_tmp = RasterStack((; affinities, qualities, target_qualities=qualities))
Rasters.rplot(rast_tmp)
rast_tmp = RasterStack((; affinities, qualities, target_qualities=modify(sparse, qualities)))

# θs = [2.5, 1.0, 0.5, 0.1, 0.01, 0.001]
θs = [1, 0.1, 0.01, 0.001, 0.0001, 0.00001]

betqs = map(θs) do θ
    connectivity_measure = ConScape.ExpectedCost(; θ, distance_transformation)
    problem = ConScape.Problem(;graph_measures, connectivity_measure, solver)
    ConScape.solve(problem, rast_tmp).betq
end
betw = cat(betqs...; dims=Dim{:theta}(θs))

Rasters.rplot(betw[Y(6.90e6 .. 6.94e6), X(175000 .. 220000)], colormap=cgrad(:magma), width=1500, height=500)


# show the distance transformation
θ = 0.1
graph_measures = (; betq=ConScape.BetweennessQweighted())
distance_transformation = nothing
connectivity_measure = ConScape.ExpectedCost(; θ, distance_transformation)
problem = ConScape.Problem(;graph_measures, connectivity_measure, solver)
workspace = init(problem, rast_tmp);

dists = ConScape.Raster(workspace.expected_costs[:,1], workspace.grid)
Makie.plot(dists)

prox = ConScape.Raster(map(x -> exp(-x/250), workspace.expected_costs[:,1]), workspace.grid)
Makie.plot(prox)

αs = 1 ./ [1, 100, 250, 500]

proxs = map(αs) do α
    ConScape.Raster(map(x -> exp(-α*x), workspace.expected_costs[:,1]), workspace.grid)
end
proxs = cat(proxs...; dims=Dim{:alpha}(αs))

Rasters.rplot(proxs[Y(6.90e6 .. 6.94e6), X(175000 .. 220000)], colormap=cgrad(:magma))


# Functionality
θ = 0.1
α = 1/500

qualities = reverse(rotr90(replace_missing(Raster(joinpath(datadir, "hab_qual_$landscape.asc")), NaN)); dims=X)
affinities = reverse(rotr90(replace_missing(Raster(joinpath(datadir, "mov_prob_$landscape.asc")), NaN)); dims=X)
qualities[(affinities .> 0) .& isnan.(qualities)] .= 1e-20

rast = RasterStack((; affinities, qualities, target_qualities=ConScape.coarse_graining(qualities, 10)))
graph_measures = (; ch=ConScape.ConnectedHabitat())
distance_transformation = (expx=t -> exp(-α*t))
connectivity_measure = ConScape.ExpectedCost(; θ, distance_transformation)
problem = ConScape.Problem(;graph_measures, connectivity_measure, solver)
workspace = init(problem, rast);

func = ConScape.solve!(workspace, problem).ch
Makie.plot(func, colormap=cgrad(:viridis))

# Flow
graph_measures = (; flow=ConScape.BetweennessKweighted())
distance_transformation = (expx=t -> exp(-α*t))
connectivity_measure = ConScape.ExpectedCost(; θ, distance_transformation)
problem = ConScape.Problem(;graph_measures, connectivity_measure, solver)
flow = ConScape.solve(problem, rast).flow
Makie.plot((flow).^(1/1.75), colormap=cgrad(:magma))

# Landscape functionality
Makie.plot(func, colormap=cgrad(:viridis))

missingval(func) === NaN
sum(x -> isnan(x) ? 0.0 : x, func)
