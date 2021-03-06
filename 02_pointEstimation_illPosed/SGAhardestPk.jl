
using Knet
# mse(ŷ,y) = (sum(abs2, y-ŷ) / length(ŷ))
# const d = 10::Int ## number of observations in a sample

## find the hardest Pᵏ for given estimator mTᵏ by running SGA with 10 random starts for γ
function findPᵏ(mTᵏ::Function, modelP::ParamModelPᵏ; atype=Array{Float32}, opt=Adam, lr=0.01, nbatch=100, nruns=200, nstarts=10, ntest=5000, uniformSphere = false, avgMaxOut = false)
    T = Float32
    lr=T(lr)
    if !uniformSphere
        xinit = rand(modelP, nstarts)
    else
        xinit = unifRand(modelP, nstarts)
    end
    optvals = copy(xinit)
    maxRisks = Vector{T}(length(xinit))

    @inbounds for i = 1:length(xinit)
        maxRisks[i], optvals[i] = optimizeSGA(mTᵏ, modelP, xinit[i]; atype=atype, opt=Adam, lr=lr, nbatch=nbatch, nruns=nruns)
    end

    maxRisk = maximum(maxRisks)
    indmaxRisk = indmax(maxRisks)
    maxγ = optvals[indmaxRisk]

    # get a better estimate of the maximum risk via MC at the hardest γ:
    z1n = allocX1n(modelP, ntest; atype=atype)
    z1n = sim!(modelP,convert(atype,maxγ),z1n)
    Tᵏ = mTᵏ(z1n)
    ψ = Ψ(modelP, convert(atype,maxγ))
    maxRisk = convert(Float32,mse(Tᵏ, ψ))
    if avgMaxOut
        avgMaxRisk = mean(maxRisks)
        return maxRisk, maxγ, avgMaxRisk
    else
        return maxRisk, maxγ
    end
end

## SGA-based inner optimization routine to find the hardest Pᵏ (using Knet w/ adam optimizer)
function optimizeSGA(mTᵏ, modelP::ParamModelPᵏ, γ::AbstractVector{T}; atype=Array{Float32}, opt=Adam, lr=T(0.01), nbatch=500, nruns=200) where T
    lossval = T(0.0)
    γ = convert(atype, γ)
    optPᵏ = optimizers(γ, opt; lr=lr)
    z1n = allocX1n(modelP, nbatch; atype=atype)
    function SGAlossPᵏ(γ,z1n)
       psi0 = Ψ(modelP, γ)
       z1n = sim!(modelP, γ, z1n)
       Tᵏ = mTᵏ(z1n)
       return -mse(Tᵏ, psi0)
    end

    if nruns>0
        @inbounds for _ in 1:nruns
            γ = convert(atype, γ)
            Pᵏlossgrad = gradloss(SGAlossPᵏ)
            gradients, lossval = Pᵏlossgrad(γ,z1n)
            update!(γ, gradients, optPᵏ)
            γ = convert(Array{Float32}, γ)
            γ = clip(γ, modelP)
        end
    else
        γ = convert(atype, γ)
        lossval = SGAlossPᵏ(γ,z1n)
        γ = convert(Array{Float32}, γ)
    end
    maxRisk = -lossval
    return maxRisk, γ
end

