
# ## TODO: replace γ = [μgrid[μidx], σgrid[σidx]] with something more generic
function riskgrid(o,nets,modelP,μgrid::AbstractVector{T},σgrid::AbstractVector{T};atype = Array{Float32}) where T
    nmc = o[:ntest]
    mTᵏ = deepcopy(nets[:mTᵏ])
    mTᵏ = convertNN(mTᵏ)
    modelTᵏ(z1n) = predictTᵏ(mTᵏ,z1n)
    # prog = Progress(length(μgrid)*length(σgrid),1) # prog = Progress(length(krange),1)
    # riskmat = zeros(T, (length(μgrid), length(σgrid)));
    riskmat = SharedArray{T}(length(μgrid), length(σgrid));
    # @time for μidx = 1:length(μgrid), σidx=1:length(σgrid)
    # @time Threads.@threads for μidx = 1:length(μgrid)
    @time @sync @parallel for μidx = 1:length(μgrid)
        for σidx = 1:length(σgrid)
            γ = [μgrid[μidx], σgrid[σidx]]
            z1n = allocX1n(modelP,nmc;atype=atype)
            z1n = sim!(modelP,γ,z1n)
            Tᵏ = modelTᵏ(z1n)
            ψ = Ψ(modelP,γ)
            riskmat[μidx, σidx] = mse(Tᵏ,ψ)
        end
    end
    # next!(prog)
    # end
    return riskmat
end
