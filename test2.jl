using NLOptControl
using Polynomials
using Plots
using Parameters
pyplot()
default(guidefont = font(12), tickfont = font(12), legendfont = font(8), titlefont = font(20))
############
# TEST DATA
############
t0 = Float64(0); tf = Float64(10);
t = Array(linspace(t0,tf,100));
α₁ =  -0.3; α₂ = 3; α₃ = -8; α₄ =  7;

γ1 = Poly([α₁,α₂,α₁]);    # state 1
γ2 = Poly([α₁,α₂,α₁,α₄]); # state 2
γ = [γ1; γ2]; numStates=length(γ);
y = [polyval(γ[st],t) for st in 1:numStates];

# evaluate the integrals
∫γ = [polyint(γ[st]) for st in 1:numStates];
Y  = [polyval(∫γ[st],t[end]) - polyval(∫γ[st],t[1]) for st in 1:numStates];
C  = [Y[st] - polyval(∫γ[st],t[end]) for st in 1:numStates]; # constant of integration
∫y = [polyval(∫γ[st],t) + C[st] for st in 1:numStates];

# evaluate the derivatives
dγ = [polyder(γ[st]) for st in 1:numStates];
dy = [polyval(dγ[st],t) for st in 1:numStates];
############
# TEST DATA
############
ps, nlp = initialize_NLP(numStates=numStates,numControls=1,Ni=1,Nck=[4]);
@pack ps = t0, tf;  # given in problem def.
@unpack Nck, Ni, t0, tf, τ, ω = ps;
di, tm, ts, ωₛ = create_intervals(t0,tf,Ni,Nck,τ,ω);
@pack ps = τ, ω, ωₛ, ts;
generate_Fake_data(nlp,ps,γ);
nlp2ocp(nlp,ps);

@unpack stateMatrix = ps;
@unpack numStates = nlp;

# interpolate function using Lagrange Polynomial
P = [zeros(Float64,Nck[int]+1,numStates) for int in 1:Ni];
for st in 1:numStates
    for int in 1:Ni
        P[int][:,st] = interpolate_lagrange(ts[int],ts[int],stateMatrix[int][1:end,st],Nck[int])
    end
end

# approximate integral using quadrature
ζ, approx_int_st = integrate_state(ps,nlp)

# calculate LGR matrices - > IMatrix and DMatrix
LGR_matrices(ps,nlp)

# approximate integral using LGRIM
ζ2, approx_int_st2 = integrate_state(ps,nlp;(:mode=>:LGRIM))

# approximate derivative using LGRDM
dζ = differentiate_state(ps,nlp)
#################
# post processing
#################
ls = 1.35;
lw = 4;

ip=plot(0,leg=:false)
for st in 1:numStates
  plot!(t,∫y[st],label=string(@sprintf("act. = %0.2f",∫y[st][end])," || st. #",st),w=lw);
end
for st in 1:numStates
    legend_bool=true;
    for int in 1:Ni
        if legend_bool
            scatter!(ts[int][1:end-1],ζ[int][st,1:Nck[int]],marker = (:pentagon, 10, 0.9, :red),leg=:bottomright,label=string(@sprintf("QUAD. = %0.2f",approx_int_st[st])," || st. #",st))
            scatter!(ts[int][1:end-1],ζ2[int][st,1:Nck[int]], marker = (:star5, 10, 0.9, :green),leg=:bottomright,label=string(@sprintf("LGR  = %0.2f",approx_int_st2[st])," || st. #",st))
        else # do not show legend a bunch of times
            scatter!(ts[int][1:end-1],ζ[int][st,1:Nck[int]],marker = (:pentagon, 10, 0.9, :red),leg=:bottomright,label= "",leg=true)
            scatter!(ts[int][1:end-1],ζ2[int][st,1:Nck[int]], marker = (:star5, 10, 0.9, :green),leg=:bottomright,label= "",leg=true)
        end
        legend_bool=false;
    end
end
xlims!(t0,tf*ls)
ylabel!("Integral")
xlabel!(string("Number of Intervals = ", Ni))

dp=plot(0,leg=:false)

for st in 1:numStates
  plot!(t,dy[st],label=string("act. state #",st),w=lw);
end
for st in 1:numStates
    legend_bool=true;  # new legend for each state
    for int in 1:Ni
        if legend_bool
            scatter!(ts[int][1:end-1],dζ[int][st,1:Nck[int]],marker = (:pentagon, 10, 0.9, :red),label=string(string("LGR")," || st. #",st),leg=:bottomright)
        else # do not show legend a bunch of times
            scatter!(ts[int][1:end-1],dζ[int][st,1:Nck[int]],marker = (:pentagon, 10, 0.9, :red),label= "",leg=true)
        end
        legend_bool=false;
    end
end
xlims!(t0,tf*ls)
ylabel!("Derivative")
xlabel!(string("State(x) = ",γ))

tF = zeros(Float64,Ni); yF =  zeros(Float64,Ni);
fp=plot(0,leg=:false);
plot!(t,y,label="act.",w=lw)
for st in 1:numStates  # currently the second state is all zeros
    for int in 1:Ni
        scatter!(ts[int],P[int][:,st],markersize =10,markershape = :rect,leg=:topright,label=string("# cp. = ",Nck[int]))
        tF[int] = ts[int][end];
        yF[int] = P[int][end,st];
    end
end
scatter!(tF,yF,markersize = 10,marker = (:star8, 10, 0.9, :black),label=string("end points"))
xlims!(t0,tf*ls)
ylabel!("State")
xlabel!("x --> really time (t)")

plot(ip,dp,fp,layout=(3,1),background_color_subplot=RGB(0.2,0.2,0.2), background_color_legend=RGB(1,1,1))
plot!(foreground_color_grid=RGB(1,1,1))