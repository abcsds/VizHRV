using GLMakie
using LSL
using TerminalMenus

# Get the available streams
streams = LSL.resolve_streams(timeout=1.0)

while isempty(streams)
    println("No streams found. Retrying...")
    streams = LSL.resolve_streams(timeout=1.0);
end

# Select the desired stream
menu = RadioMenu([source_id(s) for s in streams], pagesize=10);
selected = request(menu);
# selected = 2
stream = streams[selected];

# Create the inlet
inlet = StreamInlet(stream);
open_stream(inlet);
sleep(0.1)

# Get the first sample
timestamp, sample = pull_sample(inlet, timeout=1.0);

# Create the Observables
sample_size = 150;
rr = Observable(zeros(Int32, sample_size));
nn = Observable(zeros(Int32, sample_size));
t = Observable(zeros(Float64, sample_size));
t_rr = Observable(zeros(Float64, sample_size));
pp_x = Observable(zeros(Int32, sample_size-1));
pp_y = Observable(zeros(Int32, sample_size-1));
title_rr = Observable("RR Interval");
title_nn = Observable("NN Interval");
title_pp = Observable("ΔRR[n] vs ΔRR[n-1]");

# Create the plots
fig = Figure();
ax_rr = Axis(fig[1, 1:5], title=title_rr, xlabel="Time (s)", ylabel="RR Interval (ms)");
ax_rr.yreversed = true;
ax_nn = Axis(fig[2, 1:5], title=title_nn, xlabel="Time (s)", ylabel="NN Interval (ms)");
ax_nn.yreversed = true;
ax_pp = Axis(fig[1:2, 6:10], title=title_pp, xlabel="ΔRR[n-1] (ms)", ylabel="ΔRR[n] (ms)");
lines!(ax_rr, t, rr, color=:blue);
lines!(ax_nn, t, nn, color=:red);
scatter!(ax_pp, pp_x, pp_y, color=:green);
linkxaxes!(ax_rr, ax_nn);
display(fig)

# Initialize the Observables
rr[] = fill(sample[1], sample_size);
t[] = fill(timestamp, sample_size);
t_rr[] = fill(timestamp, sample_size);
i = 1
while true
    if i > sample_size
        break
    end
    timestamp, sample = pull_sample(inlet, timeout=1.0);
    if timestamp == 0.0 || sample[1] < 0
        continue
    end
    rr[][i] = sample[1]
    if i == 1
        t[][i] = timestamp
        t_rr[][i] = timestamp
        nn[][i] = 0.0
    else
        t_rr[][i] = t[][i-1] + (sample[1] / 1000)
        t[][i] = timestamp
        nn[][i] = sample[1] - rr[][i-1]
        pp_x[][i-1] = rr[][i-1]
        pp_y[][i-1] = rr[][i]
    end
    # fill the rest of the arrays
    rr[][i+1:end] = repeat([rr[][i]], length(rr[])-i)
    nn[][i+1:end] = repeat([nn[][i]], length(nn[])-i)
    t[][i+1:end] = repeat([t[][i]], length(t[])-i)
    t_rr[][i+1:end] = repeat([t_rr[][i]], length(t_rr[])-i)

    # Update the plot
    rr[] = rr[]
    nn[] = nn[]
    t[] = t[]
    t_rr[] = t_rr[]
    pp_x[] = pp_x[]
    pp_y[] = pp_y[]
    println("$i at t: $(t[][i]) ($timestamp) : $(sample[1])")
    autolimits!(ax_rr)
    autolimits!(ax_nn)
    autolimits!(ax_pp)
    i+=1
end

# Update the plot
while true
    timestamp, sample = pull_sample!(sample, inlet, timeout=1.0)
    if timestamp == 0.0 || sample[1] < 0
        continue
    end
    println("t: $timestamp : $(sample[1])")
    rr[] = [rr[][2:end]; sample[1]];
    t_rr[] = [t[][2:end]; t[][end] + (sample[1] / 1000)];
    t[] = [t[][2:end]; timestamp];
    nn[] = [nn[][2:end]; sample[1] - rr[][end-1]];
    pp_x[] = [pp_x[][2:end]; rr[][end-1]];
    pp_y[] = [pp_y[][2:end]; rr[][end]];
    autolimits!(ax_rr)
    autolimits!(ax_nn)
    autolimits!(ax_pp)
end