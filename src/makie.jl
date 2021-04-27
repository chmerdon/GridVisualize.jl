include("flippablelayout.jl")
using .FlippableLayout

function initialize!(p::GridVisualizer,::Type{MakieType})
    Makie=p.context[:Plotter]

    # Check for version compatibility
    version_min=v"0.17.4"
    version_max=v"0.19"
    
    version_installed=PkgVersion.Version(Makie.AbstractPlotting)

    if version_installed<version_min
        error("Outdated version $(version_installed) of AbstractPlotting. Please upgrade to at least $(version_min)")
    end
    
    if version_installed>=version_max
        @warn("Possibly breaking version $(version_installed) of AbstractPlotting.")
    end

    # Prepare flippable layout
    FlippableLayout.setmakie!(Makie)
    layout=p.context[:layout]
    parent,flayout=flayoutscene(resolution=p.context[:resolution])
    p.context[:figure]=parent
    p.context[:flayout]=flayout
    for I in CartesianIndices(layout)
        ctx=p.subplots[I]
        ctx[:figure]=parent
        ctx[:flayout]=flayout
    end
    Makie.display(parent)
    
    parent
end

add_scene!(ctx,ax)=ctx[:flayout][ctx[:subplot]...]=ax


function reveal(p::GridVisualizer,::Type{MakieType})
    Makie=p.context[:Plotter]
    
    for xctx in p.subplots
        if haskey(xctx,:rawdata)
            xctx[:data][]=xctx[:rawdata]
        end
    end
    p.context[:figure]
end

function reveal(ctx::SubVis,TP::Type{MakieType})
    yieldwait(ctx[:flayout])
    if ctx[:show]||ctx[:reveal]
        reveal(ctx[:GridVisualizer],TP)
    end
end


function save(fname,p,::Type{MakieType})
    Makie=p.context[:Plotter]
    Makie.save(fname, p.context[:figure])
end








"""

     scene_interaction(update_scene,view,switchkeys::Vector{Symbol}=[:nothing])   

Control multiple scene elements via keyboard up/down keys. 
Each switchkey is assumed to correspond to one of these elements.
Pressing a switch key transfers control to its associated element.

Control of values of the current associated element is performed
by triggering change values via up/down (± 1)  resp. page_up/page_down (±10) keys

The update_scene callbac gets passed the change value and the symbol.
"""
function scene_interaction(update_scene,scene,Makie,switchkeys::Vector{Symbol}=[:nothing])
    function _inscene(scene,pos)
        area=scene.px_area[]
        pos[1]>area.origin[1] &&
            pos[1] < area.origin[1]+area.widths[1] &&
            pos[2]>area.origin[2] &&
            pos[2] < area.origin[2]+area.widths[2]
    end

    # Initial active switch key is the first in the vector passed
    activeswitch=Makie.Node(switchkeys[1])
    # Handle mouse position within scene-
    mouseposition=Makie.Node((0,0))
    Makie.on(m->mouseposition[]=m, scene.events.mouseposition)

    # Set keyboard event callback
    Makie.on(scene.events.keyboardbuttons) do buttons
        if _inscene(scene,mouseposition[])
            # On pressing a switch key, pass control
            for i=1:length(switchkeys)
                if switchkeys[i]!=:nothing && Makie.ispressed(scene,getproperty(Makie.Keyboard,switchkeys[i]))
                    activeswitch[]=switchkeys[i]
                    update_scene(0,switchkeys[i])
                    return
                end
            end
            
            # Handle change values via up/down control
            if Makie.ispressed(scene, Makie.Keyboard.up)
                update_scene(1,activeswitch[])
            elseif Makie.ispressed(scene, Makie.Keyboard.down)
                update_scene(-1,activeswitch[])
            elseif Makie.ispressed(scene, Makie.Keyboard.page_up)
                update_scene(10,activeswitch[])
            elseif Makie.ispressed(scene, Makie.Keyboard.page_down)
                update_scene(-10,activeswitch[])
            end
        end
    end
end


makestatus(grid::ExtendableGrid)="p: $(num_nodes(grid)) t: $(num_cells(grid)) b: $(num_bfaces(grid))"


scenekwargs(ctx)=Dict(:xticklabelsize => 0.5*ctx[:fontsize],
                      :yticklabelsize => 0.5*ctx[:fontsize],
                      :zticklabelsize => 0.5*ctx[:fontsize],
                      :xlabelsize => 0.5*ctx[:fontsize],
                      :ylabelsize => 0.5*ctx[:fontsize],
                      :zlabelsize => 0.5*ctx[:fontsize],
                      :xlabeloffset => 20,
                      :ylabeloffset => 20,
                      :zlabeloffset => 20,
                      :titlesize => ctx[:fontsize])

############################################################################################################
#1D grid

function gridplot!(ctx, TP::Type{MakieType}, ::Type{Val{1}}, grid)
    
    Makie=ctx[:Plotter]
    nregions=num_cellregions(grid)
    nbregions=num_bfaceregions(grid)
    
    function basemesh(grid)
        coord=vec(grid[Coordinates])
        xmin=minimum(coord)
        xmax=maximum(coord)
        h=(xmax-xmin)/40.0
        ncoord=length(coord)
        points=Vector{Point2f0}(undef,0)
        for i=1:ncoord
            push!(points,Point2f0(coord[i],h))
            push!(points,Point2f0(coord[i],-h))
        end
        points
    end

    function regionmesh(grid,iregion)
        coord=vec(grid[Coordinates])
        cn=grid[CellNodes]
        cr=grid[CellRegions]
        ncells=length(cr)
        points=Vector{Point2f0}(undef,0)
        for i=1:ncells
            if cr[i]==iregion
                push!(points,Point2f0(coord[cn[1,i]],0))
                push!(points,Point2f0(coord[cn[2,i]],0))
            end
        end
        points
    end

    function bmesh(grid,ibreg)
        coord=vec(grid[Coordinates])
        xmin=minimum(coord)
        xmax=maximum(coord)
        h=(xmax-xmin)/20.0
        nbfaces=num_bfaces(grid)
        bfacenodes=grid[BFaceNodes]
        bfaceregions=grid[BFaceRegions]
        points=Vector{Point2f0}(undef,0)
        for ibface=1:nbfaces
            if bfaceregions[ibface]==ibreg
                push!(points,Point2f0(coord[bfacenodes[1,ibface]],h))
                push!(points,Point2f0(coord[bfacenodes[1,ibface]],-h))
            end
        end
        points
    end

    
    if !haskey(ctx,:scene)
        ctx[:scene]=Makie.Axis(ctx[:figure];title=ctx[:title], scenekwargs(ctx)...)
        ctx[:grid]=Makie.Node(grid)
        cmap=region_cmap(nregions)
        Makie.linesegments!(ctx[:scene],Makie.lift(g->basemesh(g), ctx[:grid]),color=:black)
        for i=1:nregions
            Makie.linesegments!(ctx[:scene],Makie.lift(g->regionmesh(g,i), ctx[:grid]) , color=cmap[i], strokecolor=:black,linewidth=4)
        end
        
        bcmap=bregion_cmap(nbregions)
        for i=1:nbregions
            Makie.linesegments!(ctx[:scene],Makie.lift(g->bmesh(g,i),ctx[:grid]), color=bcmap[i], linewidth=4)
        end
        add_scene!(ctx,ctx[:scene])
        Makie.display(ctx[:figure])
    else
        ctx[:grid][]=grid
    end
    reveal(ctx,TP)
end

# 1D function
function scalarplot!(ctx, TP::Type{MakieType}, ::Type{Val{1}}, grid,func)
    Makie=ctx[:Plotter]

    if ctx[:title]==""
        ctx[:title]=" "
    end

    # ... keep this for the case we are unsorted
    function lsegs(grid,func,color;prev=nothing)
        if prev==nothing
            points=Vector{Point2f0}(undef,0)
            colors=Vector{typeof(color)}(undef,0)
        else
            points=prev.p
            colors=prev.c
        end
        cellnodes=grid[CellNodes]
        coord=grid[Coordinates]
        for icell=1:num_cells(grid)
            i1=cellnodes[1,icell]
            i2=cellnodes[2,icell]
            x1=coord[1,i1]
            x2=coord[1,i2]
            push!(points,Point2f0(x1,func[i1]))
            push!(points,Point2f0(x2,func[i2]))
            push!(colors,color)
            push!(colors,color)
        end
        (p=points,c=colors)
    end
    
    function  xlines(ctx,grid,func,dx,dy;prev=nothing)

        coord=grid[Coordinates]
        points=[Point2f0(coord[1,i],func[i]) for i=1:length(func)]
        colors=fill(RGB(ctx[:color]),length(points))

        mpoints=markerpoints(points,ctx[:markers],Diagonal([1/dx, 1/dy]))
        mcolors=fill(RGB(ctx[:color]),length(mpoints))
        
        if isnothing(prev)
            allpoints=points
            allcolors=colors
            allmpoints=mpoints
            allmcolors=mcolors
        else
            push!(prev.p,Point2f0(NaN,NaN))
            push!(prev.c,RGB(ctx[:color]))
            
            allpoints=vcat(prev.p,points)
            allcolors=vcat(prev.c,colors)
            allmpoints=vcat(prev.mp,mpoints)
            allmcolors=vcat(prev.mc,mcolors)
        end
        (p=allpoints,c=allcolors,mp=allmpoints,mc=allmcolors)
    end
    
    coord=grid[Coordinates]
    xlimits=ctx[:xlimits]
    ylimits=ctx[:flimits]
    xmin=coord[1,1]
    xmax=coord[1,end]
    if xlimits[1]<xlimits[2]
        xmin=xlimits[1]
        xmax=xlimits[2]
    end
    ext=extrema(func)
    ymin=ext[1]
    ymax=ext[2]
    if ylimits[1]<ylimits[2]
        ymin=ylimits[1]
        ymax=ylimits[2]
    end
    

    if !haskey(ctx,:scene)
        ctx[:xtitle]=Makie.Node(ctx[:title])
        ctx[:scene]=Makie.Axis(ctx[:figure]; title=Makie.lift(a->a,ctx[:xtitle]),scenekwargs(ctx)...)
        coord=grid[Coordinates]
        ctx[:rawdata]=xlines(ctx,grid,func,xmax-xmin,ymax-ymin)
        ctx[:data]=Makie.Node(ctx[:rawdata])

        Makie.scatter!(ctx[:scene],[Point2f0(xmin,ymin),Point2f0(xmax,ymax)],color=:white,markersize=0.0,strokewidth=0)
        Makie.lines!(ctx[:scene],Makie.lift(a->a.p,ctx[:data]),color=Makie.lift(a->a.c,ctx[:data]),
                     linewidth=2)
        
        Makie.scatter!(ctx[:scene],
                       Makie.lift(a->a.mp,ctx[:data]),
                       color=Makie.lift(a->a.mc,ctx[:data]),
                       marker=ctx[:markertype],
                       markersize=ctx[:markersize])

        add_scene!(ctx,ctx[:scene])
        Makie.display(ctx[:figure])
    else
        if ctx[:clear]
            ctx[:rawdata]=xlines(ctx,grid,func,xmax-xmin,ymax-ymin)
        else
            ctx[:rawdata]=xlines(ctx,grid,func,xmax-xmin,ymax-ymin;prev=ctx[:rawdata])
        end
        ctx[:xtitle][]=ctx[:title]
        yieldwait(ctx[:flayout])
    end
    reveal(ctx,TP)
end

#######################################################################################
# 2D grid
function gridplot!(ctx, TP::Type{MakieType}, ::Type{Val{2}},grid)
    Makie=ctx[:Plotter]
    nregions=num_cellregions(grid)
    nbregions=num_bfaceregions(grid)


    if !haskey(ctx,:scene)
        ctx[:scene]=Makie.Axis(ctx[:figure];title=ctx[:title],aspect=Makie.DataAspect(),scenekwargs(ctx)...)
        ctx[:grid]=Makie.Node(grid)
        cmap=region_cmap(nregions)

        
        for i=1:nregions
            Makie.poly!(ctx[:scene],Makie.lift(g->regionmesh(g,i), ctx[:grid]) , color=cmap[i], strokecolor=:black)
        end

        bcmap=bregion_cmap(nbregions)
        for i=1:nbregions
            Makie.linesegments!(ctx[:scene],Makie.lift(g->bfacesegments(g,i),ctx[:grid]) , color=bcmap[i], linewidth=4)
        end
        add_scene!(ctx,ctx[:scene])
        Makie.display(ctx[:figure])
    else
        ctx[:grid][]=grid
    end
    reveal(ctx,TP)
end



# 2D function
function scalarplot!(ctx, TP::Type{MakieType}, ::Type{Val{2}},grid, func)
    Makie=ctx[:Plotter]
    
    function make_mesh(grid::ExtendableGrid,func,elevation)
        coord=grid[Coordinates]
        npoints=num_nodes(grid)
        cellnodes=grid[CellNodes]
        if elevation ≈ 0.0
            points=[Point2f0(coord[1,i],coord[2,i]) for i=1:npoints]
        else
            points=[Point3f0(coord[1,i],coord[2,i],func[i]*elevation) for i=1:npoints]
        end
        faces=[TriangleFace(cellnodes[1,i],cellnodes[2,i],cellnodes[3,i]) for i=1:size(cellnodes,2)]
        Mesh(points,faces)
    end

    function isolevels(ctx,func)
        flimits=ctx[:flimits]
        if flimits[1]<flimits[2]
            collect(LinRange(flimits[1],flimits[2],ctx[:isolines]))
        else
            limits=extrema(func)
            collect(LinRange(limits[1],limits[2],ctx[:isolines]))
        end
    end
    
    if !haskey(ctx,:scene)
        ctx[:data]=Makie.Node((g=grid,f=func,e=ctx[:elevation],t=ctx[:title],l=isolevels(ctx,func)))
        ctx[:scene]=Makie.Axis(ctx[:figure];
                               title=Makie.lift(data->data.t,ctx[:data]),
                               aspect=Makie.DataAspect(),
                               scenekwargs(ctx)...)
        flimits=ctx[:flimits]
        if flimits[1]<flimits[2]
            crange=flimits
        else
            crange=Makie.AbstractPlotting.Automatic()
        end


        Makie.poly!(ctx[:scene],
                    Makie.lift(data->make_mesh(data.g,data.f,data.e),ctx[:data]),
                    color=Makie.lift(data->data.f,ctx[:data]),
                    colorrange=crange,
                    colormap=ctx[:colormap])
        
        Makie.linesegments!(ctx[:scene],
                            Makie.lift(data->marching_triangles(data.g,data.f,data.l),ctx[:data]),
                            color=:black,
                            linewidth=1)
        
        add_scene!(ctx,ctx[:scene])
        Makie.display(ctx[:figure])
    else
        ctx[:data][]=(g=grid,f=func,e=ctx[:elevation],t=ctx[:title],l=isolevels(ctx,func))
    end
    reveal(ctx,TP)
end


#######################################################################################
#######################################################################################
# 3D Grid
function xyzminmax(grid::ExtendableGrid)
    coord=grid[Coordinates]
    ndim=size(coord,1)
    xyzmin=zeros(ndim)
    xyzmax=ones(ndim)
    for idim=1:ndim
        @views mn,mx=extrema(coord[idim,:])
        xyzmin[idim]=mn
        xyzmax[idim]=mx
    end
    xyzmin,xyzmax
end

"""
   makeaxis3d(ctx)

Dispatch between LScene and new Axis3. Axis3 does not allow zoom, so we
support LScene in addition.
"""
function makeaxis3d(ctx)
    Makie=ctx[:Plotter]
    if ctx[:scene3d]=="LScene"
        Makie.LScene(ctx[:figure])
    else
        Makie.Axis3(ctx[:figure];
                            aspect=:data,
                            viewmode=:fitzoom,
                            elevation=ctx[:elev]*π/180,
                            azimuth=ctx[:azim]*π/180,
                            perspectiveness=ctx[:perspectiveness],
                            title=Makie.lift(data->data.t,ctx[:data]),
                            scenekwargs(ctx)...)
    end
end

"""
   makescene3d(ctx)

Complete scene with title and status line showing interaction state.
This uses a gridlayout and its  protrusion capabilities.
"""
function makescene3d(ctx)
    Makie=ctx[:Plotter]
    GL=Makie.GridLayout(parent=ctx[:figure],default_rowgap=0)
    if ctx[:scene3d]=="LScene"
        # Put the title into protrusion space on top  of the scene
        GL[1,1,Makie.Top()   ]=Makie.Label(ctx[:figure]," $(Makie.lift(data->data.t,ctx[:data])) ",tellwidth=false,height=30,textsize=ctx[:fontsize])
    end
    GL[1,1               ]=ctx[:scene]
    # Put the status label into protrusion space on the bottom of the scene
    GL[1,1,Makie.Bottom()]=Makie.Label(ctx[:figure],ctx[:status],tellwidth=false,height=30,textsize=0.5*ctx[:fontsize])
    GL
end

const keyboardhelp=
"""
Keyboard interactions:
          x: control xplane
          y: control yplane
          z: control zplane
          l: control isolevel
    up/down: fine control control value
pgup/pgdown: coarse control control value
          h: print this message
"""


function gridplot!(ctx, TP::Type{MakieType}, ::Type{Val{3}}, grid)

    make_mesh(pts,fcs)=Mesh(meta(pts,normals=normals(pts, fcs)),fcs)
    
    nregions=num_cellregions(grid)
    nbregions=num_bfaceregions(grid)
    
    Makie=ctx[:Plotter]
    xyzmin,xyzmax=xyzminmax(grid)
    xyzstep=(xyzmax-xyzmin)/100
    
    function adjust_planes()
        ctx[:xplane]=max(xyzmin[1],min(xyzmax[1],ctx[:xplane]) )
        ctx[:yplane]=max(xyzmin[2],min(xyzmax[2],ctx[:yplane]) )
        ctx[:zplane]=max(xyzmin[3],min(xyzmax[3],ctx[:zplane]) )
    end

    adjust_planes()

    

    if !haskey(ctx,:scene)

        ctx[:data]=Makie.Node((g=grid,x=ctx[:xplane],y=ctx[:yplane],z=ctx[:zplane],t=ctx[:title]))
        ctx[:scene]=makeaxis3d(ctx)
        
        ############# Interior cuts
        if ctx[:interior]
            cmap=region_cmap(nregions)
            ctx[:celldata]=Makie.lift(
                d->extract_visible_cells3D(d.g,
                                           (d.x,d.y,d.z),
                                           primepoints=hcat(xyzmin,xyzmax),
                                           Tp=Point3f0,
                                           Tf=GLTriangleFace),
                ctx[:data])
            ctx[:cellmeshes]=Makie.lift(d->[make_mesh(d[1][i],d[2][i]) for i=1:nregions], ctx[:celldata])
            for i=1:nregions
                Makie.mesh!(ctx[:scene],Makie.lift(d->d[i], ctx[:cellmeshes]),
                            color=cmap[i],
                            backlight=1f0
                            )
                if ctx[:edges]
                    Makie.wireframe!(ctx[:scene],Makie.lift(d->d[i], ctx[:cellmeshes]),strokecolor=:black)
                end
            end
        end
        
        bcmap=bregion_cmap(nbregions)
        ############# Visible boundary faces
        if true 
            ctx[:facedata]=Makie.lift(
                d->extract_visible_bfaces3D(d.g,
                                            (d.x,d.y,d.z),
                                            primepoints=hcat(xyzmin,xyzmax),
                                            Tp=Point3f0,
                                            Tf=GLTriangleFace),
                ctx[:data])
            ctx[:facemeshes]=Makie.lift(d->[make_mesh(d[1][i],d[2][i]) for i=1:nbregions], ctx[:facedata])
            
            for i=1:nbregions
                Makie.mesh!(ctx[:scene],Makie.lift(d->d[i], ctx[:facemeshes]),
                            color=bcmap[i],
                            backlight=1f0
                            )
                if ctx[:edges]
                    Makie.wireframe!(ctx[:scene],Makie.lift(d->d[i], ctx[:facemeshes]),strokecolor=:black)
                end
            end
        end
        
        ############# Transparent outline
        if ctx[:outline]
            
            ctx[:outlinedata]=Makie.lift(d->extract_visible_bfaces3D(d.g,
                                                                     xyzmax,
                                                                     primepoints=hcat(xyzmin,xyzmax),
                                                                     Tp=Point3f0,
                                                                     Tf=GLTriangleFace),
                                         ctx[:data])
            ctx[:outlinemeshes]=Makie.lift(d->[make_mesh(d[1][i],d[2][i]) for i=1:nbregions], ctx[:outlinedata])
            for i=1:nbregions
                Makie.mesh!(ctx[:scene],Makie.lift(d->d[i], ctx[:outlinemeshes]),
                            color=(bcmap[i],ctx[:alpha]),
                            transparency=true,
                            backlight=1f0
                            )
            end
        end
        
        
        
        
        ##### Interaction
        scene_interaction(ctx[:scene].scene,Makie,[:z,:y,:x,:q]) do delta,key
            if key==:x
                ctx[:xplane]+=delta*xyzstep[1]
                ctx[:status][]=@sprintf("x=%.3g",ctx[:xplane])
            elseif key==:y
                ctx[:yplane]+=delta*xyzstep[2]
                ctx[:status][]=@sprintf("y=%.3g",ctx[:yplane])
            elseif key==:z
                ctx[:zplane]+=delta*xyzstep[3]
                ctx[:status][]=@sprintf("z=%.3g",ctx[:zplane])
            elseif key==:q
                ctx[:status][]=" "
            end
            adjust_planes()
            ctx[:data][]=(g=grid,x=ctx[:xplane],y=ctx[:yplane],z=ctx[:zplane],t=ctx[:title])
        end

        ctx[:status]=Makie.Node(" ")
        add_scene!(ctx,makescene3d(ctx))
        Makie.display(ctx[:figure])
    else
        ctx[:data][]=(g=grid,x=ctx[:xplane],y=ctx[:yplane],z=ctx[:zplane],t=ctx[:title])
    end
    reveal(ctx,TP)
end

# 3d function
function scalarplot!(ctx, TP::Type{MakieType}, ::Type{Val{3}}, grid , func)
    
    make_mesh(pts,fcs)=Mesh(pts,fcs)
    
    function make_mesh(pts,fcs,vals)
        colors = Makie.AbstractPlotting.interpolated_getindex.((cmap,), vals, (fminmax,))
        GeometryBasics.Mesh(meta(pts, color=colors,normals=normals(pts, fcs)), fcs)
    end
        
    
    nregions=num_cellregions(grid)
    nbregions=num_bfaceregions(grid)
    
    Makie=ctx[:Plotter]
    cmap = Makie.to_colormap(ctx[:colormap])
    xyzmin,xyzmax=xyzminmax(grid)
    xyzstep=(xyzmax-xyzmin)/100

    fminmax=extrema(func)

    flimits=ctx[:flimits]
    if flimits[1]<flimits[2]
        fminmax=(flimits[1],flimits[2])
    end
    
    fstep=(fminmax[2]-fminmax[1])/100
    if fstep≈0
        fstep=0.1
    end
    
    function adjust_planes()
        ctx[:xplane]=max(xyzmin[1],min(xyzmax[1],ctx[:xplane]) )
        ctx[:yplane]=max(xyzmin[2],min(xyzmax[2],ctx[:yplane]) )
        ctx[:zplane]=max(xyzmin[3],min(xyzmax[3],ctx[:zplane]) )
        ctx[:flevel]=max(fminmax[1],min(fminmax[2],ctx[:flevel]))
    end
    
    adjust_planes()


    makeplanes(x,y,z)=[[1,0,0,-x], 
                       [0,1,0,-y], 
                       [0,0,1,-z]]
    
    if !haskey(ctx,:scene)
        ctx[:data]=Makie.Node((g=grid,f=func,x=ctx[:xplane],y=ctx[:yplane],z=ctx[:zplane],l=ctx[:flevel],t=ctx[:title]))
        ctx[:scene]=makeaxis3d(ctx)

        #### Transparent outlne
        if ctx[:outline]
            ctx[:outlinedata]=Makie.lift(d->extract_visible_bfaces3D(d.g,
                                                                     xyzmax,
                                                                     primepoints=hcat(xyzmin,xyzmax),
                                                                     Tp=Point3f0,
                                                                     Tf=GLTriangleFace),
                                         ctx[:data])
            ctx[:facemeshes]=Makie.lift(d->[make_mesh(d[1][i],d[2][i]) for i=1:nbregions], ctx[:outlinedata])
            bcmap=bregion_cmap(nbregions)
            for i=1:nbregions
                Makie.mesh!(ctx[:scene],Makie.lift(d->d[i], ctx[:facemeshes]),
                            color=(bcmap[i],ctx[:alpha]),
                            transparency=true,
                            backlight=1f0
                            )
            end
        end

        #### Plane sections and isosurfaces
        Makie.mesh!(ctx[:scene],
                    Makie.lift(d->make_mesh(marching_tetrahedra(d.g,
                                                                d.f,
                                                                makeplanes(d.x,d.y,d.z),
                                                                [d.l],
                                                                primepoints=hcat(xyzmin,xyzmax),
                                                                primevalues=fminmax,
                                                                Tp=Point3f0,
                                                                Tf=GLTriangleFace,
                                                                Tv=Float32)...),ctx[:data]),
                    backlight=1f0)

        #### Interactions
        scene_interaction(ctx[:scene].scene,Makie,[:z,:y,:x,:l,:q]) do delta,key
            if key==:x
                ctx[:xplane]+=delta*xyzstep[1]
                ctx[:status][]=@sprintf("x=%.3g",ctx[:xplane])
            elseif key==:y
                ctx[:yplane]+=delta*xyzstep[2]
                ctx[:status][]=@sprintf("y=%.3g",ctx[:yplane])
            elseif key==:z
                ctx[:zplane]+=delta*xyzstep[3]
                ctx[:status][]=@sprintf("z=%.3g",ctx[:zplane])
            elseif key==:l
                ctx[:flevel]+=delta*fstep
                ctx[:status][]=@sprintf("l=%.3g",ctx[:flevel])
            elseif key==:q
                ctx[:status][]=" "
            end
            adjust_planes()
            ctx[:data][]=(g=grid,f=func,x=ctx[:xplane],y=ctx[:yplane],z=ctx[:zplane],l=ctx[:flevel],t=ctx[:title])
        end
        
        ctx[:status]=Makie.Node(" ")
        add_scene!(ctx,makescene3d(ctx))
        Makie.display(ctx[:figure])
    else
        ctx[:data][]=(g=grid,f=func,x=ctx[:xplane],y=ctx[:yplane],z=ctx[:zplane],l=ctx[:flevel],t=ctx[:title])
    end
    reveal(ctx,TP)
end






        # TODO: allow aspect scaling
        # if ctx[:aspect]>1.0
        #     Makie.scale!(ctx[:scene],ctx[:aspect],1.0)
        # else
        #     Makie.scale!(ctx[:scene],1.0,1.0/ctx[:aspect])
        # end

        # TODO: use distinguishable colors
        # http://juliagraphics.github.io/Colors.jl/stable/colormapsandcolorscales/#Generating-distinguishable-colors-1
    
# TODO: a priori angles aka pyplot3D
# rect = ctx[:scene]
# azim=ctx[:azim]
# elev=ctx[:elev]
# arr = normalize([cosd(azim/2), 0, sind(azim/2), -sind(azim/2)])
# Makie.rotate!(rect, Makie.Quaternionf0(arr...))

  
# 3 replies
# Julius Krumbiegel  5 hours ago
# try lines(x, y, axis = (limits = lims,)), the other keyword arguments go to the plot
# Julius Krumbiegel  5 hours ago
# although I think it should be targetlimits because the limits are computed from them usually, considering that there might be aspect constraints that should be met or linked axes (edited) 
# Christophe Meyer  4 hours ago
# Thanks!  lines(x, y, axis = (targetlimits = lims,))  indeed makes the limits update.^
# I found that autolimits!(axis) gave good results, even better than me manually computing limits!