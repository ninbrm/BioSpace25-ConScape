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

landscape = "1000"
# The way the ascii is read in is reversed and rotated from what GDAL does
qualities = reverse(rotr90(replace_missing(Raster(joinpath(datadir, "hab_qual_$landscape.asc")), NaN)); dims=X)
Makie.plot(qualities, colormap=cgrad([:lightgrey, :green]))
affinities = reverse(rotr90(replace_missing(Raster(joinpath(datadir, "mov_prob_$landscape.asc")), NaN)); dims=X)
Makie.plot(qualities, colormap=cgrad(:acton))

qualities[(affinities .> 0) .& isnan.(qualities)] .= 1e-20
rast = RasterStack((; affinities, qualities, target_qualities=qualities))
Rasters.rplot(rast)


# show effect of theta
graph_measures = (; betq=ConScape.BetweennessQweighted())
distance_transformation = (nodist=nothing)
solver = ConScape.MatrixSolver()

qualities[:,:] .= 0
qualities[60,70] = 1
qualities[50, 105] = 1
Makie.plot(qualities, colormap=cgrad([:lightgrey, :green]))
#rast = RasterStack((; affinities, qualities, target_qualities=modify(sparse, qualities)))
rast_tmp = RasterStack((; affinities, qualities, target_qualities=qualities))
Rasters.rplot(rast_tmp)

θs = [2.5, 1.0, 0.5, 0.1, 0.01, 0.001]

betqs = map(θs) do θ
    connectivity_measure = ConScape.ExpectedCost(; θ, distance_transformation)
    problem = ConScape.Problem(;graph_measures, connectivity_measure, solver)
    ConScape.solve(problem, rast_tmp).betq
end
betw = cat(betqs...; dims=Dim{:theta}(θs))

Rasters.rplot(betw[Y(6.91e6 .. 6.96e6), X(175000 .. 220000)], colormap=cgrad(:magma))


# show the distance transformation
θ = 0.1
graph_measures = (; betq=ConScape.BetweennessQweighted())
distance_transformation = nothing
connectivity_measure = ConScape.ExpectedCost(; θ, distance_transformation)
problem = ConScape.Problem(;graph_measures, connectivity_measure, solver)
workspace = init(problem, rast);

dists = ConScape.Raster(workspace.expected_costs[:,4300], workspace.grid)
Makie.plot(dists)

prox = ConScape.Raster(map(x -> exp(-x/75), workspace.expected_costs[:,4300]), workspace.grid)
Makie.plot(prox)


# Functionality
graph_measures = (; ch=ConScape.ConnectedHabitat())
connectivity_measure = ConScape.ExpectedCost(; θ, distance_transformation)
problem = ConScape.Problem(;graph_measures, connectivity_measure, solver)
func = ConScape.solve(problem, rast).ch
Makie.plot(func, colormap=cgrad(:viridis))


# Flow
graph_measures = (; betwk=ConScape.BetweennessKweighted())
connectivity_measure = ConScape.ExpectedCost(; θ, distance_transformation)
problem = ConScape.Problem(;graph_measures, connectivity_measure, solver)
flow = ConScape.solve(problem, rast).betwk
Makie.plot(flow, colormap=cgrad(:magma))


