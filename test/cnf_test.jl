using OrdinaryDiffEq
using Flux, DiffEqFlux
using Test
using Distributions
using Distances
using LinearAlgebra, Tracker

#test for default base distribution and monte_carlo = true
nn = Chain(Dense(1, 1, tanh))
data_train = [Float32(rand(Beta(7,7))) for i in 1:100]
tspan = (0.0,10.0)
ffjord_test_mc = FFJORD(nn,tspan,monte_carlo=true)

function loss_adjoint(θ)
    logpx = [ffjord_test_mc(x,θ) for x in data_train]
    loss = -mean(logpx)
end

res = DiffEqFlux.sciml_train(loss_adjoint, ffjord_test_mc.p,
                                        ADAM(0.1),
                                        maxiters = 1000)

θopt = res.minimizer
data_validate = [Float32(rand(Beta(7,7))) for i in 1:100]
actual_pdf = [pdf(Beta(7,7),r) for r in data_validate]
#use direct trace calculation for predictions
learned_pdf = [exp(ffjord_test_mc(r,θopt,false)) for r in data_validate]
@test totalvariation(learned_pdf, actual_pdf)/100 < 0.25

#test for alternative base distribution and monte_carlo = false
nn = Chain(Dense(1, 1, tanh))
data_train = [Float32(rand(Normal(6.0,0.7))) for i in 1:100]
tspan = (0.0,10.0)
ffjord_test = FFJORD(nn,tspan,base_dist=Normal(0,2))

res = DiffEqFlux.sciml_train(loss_adjoint, ffjord_test.p,
                                          ADAM(0.1),
                                          maxiters = 1000)

θopt = res.minimizer
data_validate = [Float32(rand(Normal(6.0,0.7))) for i in 1:100]
actual_pdf = [pdf(Normal(6.0,0.7),r) for r in data_validate]
learned_pdf = [exp(ffjord_test(r, θopt)) for r in data_validate]

@test totalvariation(learned_pdf, actual_pdf)/100 < 0.10

#test for alternative multivariate distribution
nn = Chain(Dense(2, 3, tanh), Dense(3, 2, tanh))
μ = zeros(2)
Σ = I + zeros(2,2)
mv_normal = MvNormal(μ, Σ)
data_train = [Float32.(rand(mv_normal)) for i in 1:100]
tspan = (0.0,10.0)
ffjord_test = FFJORD(nn,tspan,monte_carlo=true)

res = DiffEqFlux.sciml_train(loss_adjoint, ffjord_test.p,
                                          ADAM(0.1), cb = cb,
                                          maxiters = 200)

θopt = res.minimizer
data_validate = [Float32.(rand(mv_normal)) for i in 1:100]
actual_pdf = [pdf(mv_normal,r) for r in data_validate]
learned_pdf = [exp(ffjord_test(r, θopt)) for r in data_validate]

@show totalvariation(learned_pdf, actual_pdf)/100
