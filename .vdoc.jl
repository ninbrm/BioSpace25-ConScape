#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#| echo: true

using ConScape, SparseArrays, LinearAlgebra
using Rasters, ArchGDAL
using ConScape.LinearSolve
using CairoMakie
#
#
#
#
#
#
#
#
#
#
#| echo: true

datadir = joinpath(dirname(pathof(ConScape)), "..", "data")
readdir(datadir)
_tempdir = mkdir(tempname());
#
#
#
#
#
#
#
#| echo: true

qualities = reverse(rotr90(replace_missing(Raster(
    joinpath(datadir, "hab_qual_200.asc")), NaN)); dims=X)
Makie.plot(qualities, colormap=cgrad([:lightgrey, :green]))
#
#
#
#
#
#
#| echo: true

affinities = reverse(rotr90(replace_missing(Raster(
    joinpath(datadir, "mov_prob_200.asc")), NaN)); dims=X)
Makie.plot(qualities, colormap=cgrad(:acton))
#
#
#
#
#
#
#
#
#
#
#
#| echo: true

qualities[(affinities .> 0) .& isnan.(qualities)] .= 1e-20;
#
#
#
#
#
#
#
#
#
#
#
#
#| echo: true

source_qualities = copy(qualities)
source_qualities[:,:] .= 0
source_qualities[250, 500] = 1

target_qualities = copy(qualities)
target_qualities[:,:] .= 0
target_qualities[350, 400] = 1

rast = RasterStack((; affinities, qualities=source_qualities, target_qualities=modify(sparse, target_qualities)))
#
#
#
#
#
#
#
#| echo: true

graph_measures = (; betw=ConScape.BetweennessQweighted())
distance_transformation = (nodist=nothing)

θs = [1, 0.1, 0.01, 0.001, 0.0001, 0.00001]

betw = map(θs) do θ
    connectivity_measure = ConScape.ExpectedCost(; θ, distance_transformation)
    problem = ConScape.Problem(;graph_measures, connectivity_measure, solver)
    ConScape.solve(problem, rast_tmp).betw
end

betw = cat(betw...; dims=Dim{:theta}(θs))
#
#
#
#
#
#
#
#| echo: true

Rasters.rplot(betw[Y(6.90e6 .. 6.94e6), X(175000 .. 220000)], colormap=cgrad(:magma), width=1500, height=500)
#
#
#
#
#
#
#
#
#| echo: true

θ = 0.1
graph_measures = (; betq=ConScape.BetweennessQweighted())
distance_transformation = nothing
connectivity_measure = ConScape.ExpectedCost(; θ, distance_transformation)

solver = ConScape.MatrixSolver()
problem = ConScape.Problem(;graph_measures, connectivity_measure, solver)
workspace = init(problem, rast_tmp);
#
#
#
#
#
#
#| echo: true

dists = ConScape.Raster(workspace.expected_costs[:,1], workspace.grid)
Makie.plot(dists)
#
#
#
#
#
#
#
#| echo: true

αs = 1 ./ [1, 100, 250, 500]

proxs = map(αs) do α
    ConScape.Raster(map(x -> exp(-α*x), workspace.expected_costs[:,1]), workspace.grid)
end
proxs = cat(proxs...; dims=Dim{:alpha}(αs))
#
#
#
#
#
#
#
#| echo: true

Rasters.rplot(proxs[Y(6.90e6 .. 6.94e6), X(175000 .. 220000)], colormap=cgrad(:magma))
#
#
#
#
#
#
#
#
#
#| echo: true

rast = RasterStack((; affinities, qualities, target_qualities=ConScape.coarse_graining(qualities, 10)))
#
#
#
#
#
#
#
#| echo: true

θ = 0.1
α = 1/500
#
#
#
#
#
#
#
#| echo: true

graph_measures = (; ch=ConScape.ConnectedHabitat())
distance_transformation = (expx=t -> exp(-α*t))
connectivity_measure = ConScape.ExpectedCost(; θ, distance_transformation)
problem = ConScape.Problem(;graph_measures, connectivity_measure, solver)
#
#
#
#
#
#
#
#| echo: true

workspace = init(problem, rast);
func = ConScape.solve!(workspace, problem).ch
#
#
#
#
#
#
#
#| echo: true

Makie.plot(func, colormap=cgrad(:viridis))
#
#
#
#
#
#
#
#
#| echo: true

graph_measures = (; flow=ConScape.BetweennessKweighted())
distance_transformation = (expx=t -> exp(-α*t))
connectivity_measure = ConScape.ExpectedCost(; θ, distance_transformation)
problem = ConScape.Problem(;graph_measures, connectivity_measure, solver)
```
#
#
#
#
#
#| echo: true

flow = ConScape.solve(problem, rast).flow
```
#
#
#
#
#
#| echo: true

Makie.plot((flow).^(1/1.75), colormap=cgrad(:magma))
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
