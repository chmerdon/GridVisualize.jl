#=

reveal=true anstelle von show=true ?
reveal(p)

2D Arrays in 1D plot wie in plts: Label als array, color als array.
Das geht auch einfach in Makie

pass=(...): kwargs für plotter
=#

initialize!(p, ::Type{PlotsType}) = nothing

function reveal(p::GridVisualizer, ::Type{PlotsType})
    Plots = p.Plotter
    subplots = Plots.Plot[]

    for i = 1:size(p.subplots, 1)
        for j = 1:size(p.subplots, 2)
            ctx = p.subplots[i, j]
            if haskey(ctx, :ax)
                push!(subplots, ctx[:ax])
                delete!(ctx, :ax)
            else
                push!(subplots, Plots.plot(; legend = false, grid = false, border = :none))
            end
        end
    end
    plt = Plots.plot(subplots...; layout = p.context[:layout], size = p.context[:size])
    if haskey(p.context, :videostream)
        Plots.frame(p.context[:videostream], plt)
    else
        Plots.gui(plt)
        plt
    end
end

function reveal(ctx::SubVisualizer, TP::Type{PlotsType})
    if ctx[:show] || ctx[:reveal]
        reveal(ctx[:GridVisualizer], TP)
    end
end

function save(fname, scene, Plots, ::Type{PlotsType})
    isnothing(scene) ? nothing : Plots.savefig(scene, fname)
end

function movie(func,
               vis::GridVisualizer,
               ::Type{PlotsType};
               file = nothing,
               format = "gif",
               kwargs...,)
    Plotter = vis.context[:Plotter]
    if !isnothing(file)
        format = lstrip(splitext(file)[2], '.')
    end
    if isdefined(Main, :PlutoRunner) || !isnothing(file)
        vis.context[:videostream] = Plotter.Animation()
    end

    func(vis)

    if !isnothing(file)
        if format == "mp4"
            Plotter.mp4(vis.context[:videostream], file)
        else
            Plotter.gif(vis.context[:videostream], file)
        end
    elseif isdefined(Main, :PlutoRunner)
        if format == "mp4"
            Plotter.mp4(vis.context[:videostream])
        else
            Plotter.gif(vis.context[:videostream])
        end
    end
end

function gridplot!(ctx, TP::Type{PlotsType}, ::Type{Val{1}}, grid)
    Plots = ctx[:Plotter]

    if !haskey(ctx, :ax)
        ctx[:ax] = Plots.plot(; title = ctx[:title])
    end
    p = ctx[:ax]

    cellregions = grid[CellRegions]
    cellnodes = grid[CellNodes]
    coord = grid[Coordinates]
    ncellregions = grid[NumCellRegions]
    bfacenodes = grid[BFaceNodes]
    bfaceregions = grid[BFaceRegions]
    nbfaceregions = grid[NumBFaceRegions]

    gridscale = ctx[:gridscale]
    xmin = minimum(coord) * gridscale
    xmax = maximum(coord) * gridscale
    h = (xmax - xmin) / 20.0

    cmap = region_cmap(ncellregions)
    for icell = 1:num_cells(grid)
        x1 = coord[1, cellnodes[1, icell]] * gridscale
        x2 = coord[1, cellnodes[2, icell]] * gridscale
        Plots.plot!(p, [x1, x1], [-h, h]; linewidth = 0.5, color = :black, label = "")
        Plots.plot!(p, [x2, x2], [-h, h]; linewidth = 0.5, color = :black, label = "")
        Plots.plot!(p,
                    [x1, x2],
                    [0, 0];
                    linewidth = 3.0,
                    color = cmap[cellregions[icell]],
                    label = "",)
    end

    cmap = bregion_cmap(nbfaceregions)
    for ibface = 1:num_bfaces(grid)
        if bfaceregions[ibface] > 0
            x1 = coord[1, bfacenodes[1, ibface]] * gridscale
            Plots.plot!(p,
                        [x1, x1],
                        [-2 * h, 2 * h];
                        linewidth = 3.0,
                        color = cmap[bfaceregions[ibface]],
                        label = "",)
        end
    end
    reveal(ctx, TP)
end

function gridplot!(ctx, TP::Type{PlotsType}, ::Type{Val{2}}, grid)
    Plots = ctx[:Plotter]
    if !haskey(ctx, :ax)
        ctx[:ax] = Plots.plot(; title = ctx[:title])
    end
    p = ctx[:ax]
    cellregions = grid[CellRegions]
    cellnodes = grid[CellNodes]
    coord = grid[Coordinates] * ctx[:gridscale]
    ncellregions = grid[NumCellRegions]
    bfacenodes = grid[BFaceNodes]
    bfaceregions = grid[BFaceRegions]
    nbfaceregions = grid[NumBFaceRegions]

    cmap = region_cmap(ncellregions)
    for icell = 1:num_cells(grid)
        inode1 = cellnodes[1, icell]
        inode2 = cellnodes[2, icell]
        inode3 = cellnodes[3, icell]
        # https://github.com/JuliaPlots/Plots.jl/issues/605
        tri = Plots.Shape([coord[1, inode1], coord[1, inode2], coord[1, inode3]],
                          [coord[2, inode1], coord[2, inode2], coord[2, inode3]])
        Plots.plot!(p, tri; color = cmap[cellregions[icell]], label = "")
    end
    for icell = 1:num_cells(grid)
        inode1 = cellnodes[1, icell]
        inode2 = cellnodes[2, icell]
        inode3 = cellnodes[3, icell]
        Plots.plot!(p,
                    [coord[1, inode1], coord[1, inode2]],
                    [coord[2, inode1], coord[2, inode2]];
                    linewidth = 0.5,
                    color = :black,
                    label = "",)
        Plots.plot!(p,
                    [coord[1, inode1], coord[1, inode3]],
                    [coord[2, inode1], coord[2, inode3]];
                    linewidth = 0.5,
                    color = :black,
                    label = "",)
        Plots.plot!(p,
                    [coord[1, inode2], coord[1, inode3]],
                    [coord[2, inode2], coord[2, inode3]];
                    linewidth = 0.5,
                    color = :black,
                    label = "",)
    end

    cmap = bregion_cmap(nbfaceregions)
    for ibface = 1:num_bfaces(grid)
        inode1 = bfacenodes[1, ibface]
        inode2 = bfacenodes[2, ibface]
        Plots.plot!(p,
                    [coord[1, inode1], coord[1, inode2]],
                    [coord[2, inode1], coord[2, inode2]];
                    linewidth = 5,
                    color = cmap[bfaceregions[ibface]],
                    label = "",)
    end
    reveal(ctx, TP)
end

function scalarplot!(ctx, TP::Type{PlotsType}, ::Type{Val{1}}, grids, parentgrid, funcs)
    grid = parentgrid
    func = funcs[1]
    legpos = Dict(:none => :none,
                  :best => :best,
                  :lt => :topleft,
                  :ct => :topcenter,
                  :rt => :topright,
                  :lc => :centerleft,
                  :rc => :centerright,
                  :lb => :bottomleft,
                  :cb => :bottomcenter,
                  :rb => :bottomright)

    Plots = ctx[:Plotter]
    if !haskey(ctx, :ax)
        ctx[:ax] = Plots.plot(; title = ctx[:title])
    end
    p = ctx[:ax]

    coord = grid[Coordinates] * ctx[:gridscale]
    xmin = coord[1, 1]
    xmax = coord[1, end]
    ymin = func[1]
    ymax = func[end]
    xlimits = ctx[:xlimits]
    ylimits = ctx[:limits]
    if xlimits[1] < xlimits[2]
        xmin = xlimits[1]
        xmax = xlimits[2]
    end
    if ylimits[1] < ylimits[2]
        ymin = ylimits[1]
        ymax = ylimits[2]
    end

    ctx[:xscale] == :log ? ctx[:xscale] = :log10 : nothing
    ctx[:yscale] == :log ? ctx[:yscale] = :log10 : nothing

    Plots.plot!(p,
                [xmin, xmax],
                [ymin, ymax];
                seriestype = :scatter,
                makersize = 0,
                markercolor = :white,
                markerstrokecolor = :white,
                label = "",)

    color = ctx[:color]
    if ctx[:cellwise] ## not checked
        cellnodes = grid[CellNodes]
        for icell = 1:num_cells(grid)
            i1 = cellnodes[1, icell]
            i2 = cellnodes[2, icell]
            x1 = coord[1, i1]
            x2 = coord[1, i2]
            if icell == 1 && ctx[:label] != " "
                Plots.plot!(p,
                            [x1, x2],
                            [func[i1], func[i2]];
                            linecolor = Plots.RGB(color...),
                            label = ctx[:label],)
            else
                Plots.plot!(p,
                            [x1, x2],
                            [func[i1], func[i2]];
                            linecolor = Plots.RGB(color...),
                            label = "",)
            end
        end
    else
        markevery = ctx[:markevery]
        markershape = ctx[:markershape]
        X = vec(coord)
        if markershape == :none
            Plots.plot!(p,
                        X,
                        func;
                        linecolor = Plots.RGB(color),
                        linewidth = ctx[:linewidth],
                        linestyle = ctx[:linestyle],
                        legend = legpos[ctx[:legend]],
                        xscale = ctx[:xscale],
                        yscale = ctx[:yscale],
                        label = ctx[:label],)
        else
            #Trick plots to use markers
            Plots.plot!(p,
                        X,
                        func;
                        linecolor = Plots.RGB(color),
                        linewidth = ctx[:linewidth],
                        linestyle = ctx[:linestyle],
                        xscale = ctx[:xscale],
                        yscale = ctx[:yscale],
                        label = "",)
            Plots.plot!(p,
                        [X[1]],
                        [func[1]];
                        markershape = markershape,
                        label = ctx[:label],
                        markersize = ctx[:markersize],
                        linecolor = Plots.RGB(color),
                        linewidth = ctx[:linewidth],
                        xscale = ctx[:xscale],
                        yscale = ctx[:yscale],
                        legend = legpos[ctx[:legend]],
                        linestyle = ctx[:linestyle],
                        markercolor = Plots.RGB(color),)
            @views Plots.plot!(p,
                               X[1:markevery:end],
                               func[1:markevery:end],
                               markercolor = Plots.RGB(color),
                               label = "",
                               linecolor = :white,
                               xscale = ctx[:xscale],
                               yscale = ctx[:yscale],
                               markershape = markershape,
                               markersize = ctx[:markersize],
                               lines = false)
        end
    end
    reveal(ctx, TP)
end

"""
$(SIGNATURES)
Return rectangular grid data + function to be splatted into Plots calls
"""
function rectdata(grid, gridscale, U)
    if dim_grid(grid) == 1 && haskey(grid, XCoordinates)
        return grid[XCoordinates] * gridscale, U
    end
    if dim_grid(grid) == 2 && haskey(grid, XCoordinates) && haskey(grid, YCoordinates)
        X = grid[XCoordinates] * gridscale
        Y = grid[YCoordinates] * gridscale
        return X, Y, transpose(reshape(U, length(X), length(Y)))
    end
    nothing
end

function scalarplot!(ctx, TP::Type{PlotsType}, ::Type{Val{2}}, grids, parentgrid, funcs)
    grid = grids[1]
    func = funcs[1]
    rdata = rectdata(grid, ctx[:gridscale], func)
    Plots = ctx[:Plotter]
    if !haskey(ctx, :ax)
        ctx[:ax] = Plots.plot(; title = ctx[:title])
    end
    if rdata == nothing
        @warn "2D scalarplot with Plots backend works only on rectangular grids with X and Y coordinate vectors"
        return reveal(ctx, TP)
    end
    p = ctx[:ax]

    levels, crange, colorbarticks = isolevels(ctx, func)
    eps = 1.0e-5
    if crange[1] == crange[2]
        eps = 1.0e-5
    else
        eps = (crange[2] - crange[1]) * 1.0e-15
    end
    colorlevels = range(crange[1] - eps, crange[2] + eps; length = ctx[:colorlevels])

    Plots.contourf!(p,
                    rdata...;
                    aspect_ratio = ctx[:aspect],
                    fill = ctx[:colormap],
                    linewidth = 0,
                    levels = colorlevels,
                    colorbar_ticks = colorbarticks,)
    Plots.contour!(p, rdata...; aspect_ratio = ctx[:aspect], c = :black, levels = levels)
    reveal(ctx, TP)
end

function vectorplot!(ctx, TP::Type{PlotsType}, ::Type{Val{2}}, grid, func)
    Plots = ctx[:Plotter]
    if !haskey(ctx, :ax)
        ctx[:ax] = Plots.plot(; title = ctx[:title])
    end
    p = ctx[:ax]
    rc, rv = vectorsample(grid, func; gridscale = ctx[:gridscale], rasterpoints = ctx[:rasterpoints], offset = ctx[:offset])
    qc, qv = quiverdata(rc, rv; vscale = ctx[:vscale], vnormalize = ctx[:vnormalize])

    Plots.quiver!(p, qc[1, :], qc[2, :]; quiver = (qv[1, :], qv[2, :]), color = :black)
    reveal(ctx, TP)
end

function streamplot!(ctx, TP::Type{PlotsType}, ::Type{Val{2}}, grid, func) end

function gridplot!(ctx, TP::Type{PlotsType}, ::Type{Val{3}}, grid)
    Plots = ctx[:Plotter]
    if !haskey(ctx, :ax)
        ctx[:ax] = Plots.plot(; title = ctx[:title])
    end
    @warn "3D gridplot with Plots backend is not available."
    reveal(ctx, TP)
end

function scalarplot!(ctx, TP::Type{PlotsType}, ::Type{Val{3}}, grids, parentgrid, funcs)
    grid = grids[1]
    func = funcs[1]
    Plots = ctx[:Plotter]
    if !haskey(ctx, :ax)
        ctx[:ax] = Plots.plot(; title = ctx[:title])
    end
    @warn "3D Scalarplot with Plots backend is not available."
    reveal(ctx, TP)
end

function customplot!(ctx, TP::Type{PlotsType}, func)
    if !haskey(ctx, :ax)
        ctx[:ax] = Plots.plot(; title = ctx[:title])
    end
    func(ctx[:ax])
    reveal(ctx, TP)
end
