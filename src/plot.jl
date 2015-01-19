## add plotting commands for various packages (Winston, PyPlot, Gadfly)

# plot(ex::Sym, a, b, args; kwargs...)  function plot
# plot([ex1, ex2, ...], a,b, args...; kwargs...) layer functions
# parametricplot([x,y,z], a, b, args...;kwargs)
# plot((ex1,ex2,[ex3]), a, b, args; kwargs...) aka parametric plot 
# vectorplot(f, x1, x2, y1, y2, nx, ny, args...; kwargs...)  (quiver is optional name?)
# contour(ex::Sym, x1, x2, y1, y2, args; kwargs...) contour plot
# plot_surface(ex::Sym, x1, x2, y1, y2, args...; kwargs...) (plot3D is mathematica, but not matplotlib)
# add_arrow(p::Vector, v::Vector) ## not symbolic!

## Implementations
#                                PyPlot     Gadfly    Winston
# plot(::Sym)                     ✓           ✓          ✓
# plot(::Vector{Sym})             .           .          .
# plot(::Tuple{Sym})              ✓           ✓(2D)      ✓(2D)
# parametricplot                  ✓           ✓(2D)      ✓(2D)
# contour(::Vector{Sym})          ✓           ✓          .
# contour3D(::Vector{Sym})        ✓           .          .
# vectorplot(::Vector{Sym})       ✓           .          .
# plot_surface(::Vector{Sym})     ✓           .          .
# add_arrow(p,v)                  ✓           .          .
# text...                         .           .          .

function prepare_parametric(exs, t0, t1)
    n = length(exs)
    (n==2) | (n==3) || throw(DimensionMismatch("parametric plot requires the initial tuple to have 2 or 3 variables"))
    vars = [SymPy.get_free_symbols(ex) for ex in exs]
    m,M = extrema(map(length,vars))
    (m == M) & (m == 1) || throw(DimensionMismatch("parametric plot requires exactly one free variable"))
    for i in 1:(n-1)
        vars[i] == vars[i+1] || error("parametric plot's free variable must be the same")
    end
    
    ts = linspace(t0, t1, 250)
    [Float64[float(convert(Function, exs[i])(t)) for t in ts] for i in 1:n] # [[xs...], [ys...], [zs...]]
end


## Try to support Winston, PyPlot, and Gadfly to varying degrees
## Basically our goal here is to massage the data and let args... and kwargs.. be from the
## plotting packages.

Jewel.@require Winston begin
    import Winston: plot, oplot
    
    function plot(ex::Sym, a, b, args...; kwargs...)
        vars = get_free_symbols(ex)
        if length(vars) == 1        
            f = convert(Function, ex)
            plot(x -> float(f(x)), a, b, args...; kwargs...)
        elseif length(vars) == 2
            f = convert(Function, ex)
            error("Make contour plot")
        end
    end
    function oplot(ex::Sym, args...; kwargs...)
        vars = get_free_symbols(ex)
        if length(vars) == 1        
            f = convert(Function, ex)
            oplot(x -> float(f(x)), args...; kwargs...)
        end
    end
    
    ## Parametric plot
    function plot(exs::(Sym...), t0::Real, t1::Real, args...; kwargs...)
        out = prepare_parametric(exs, t0, t1)
        n = length(exs)
        if n == 2
            plot(out..., args...; kwargs...)
        elseif n == 3
            error("No 3D plotting in Winston")
        end
    end

    function contour(ex::Sym, x1,x2, y1, y2, args...; kwargs...)
        vars = get_free_symbols(ex)
        length(vars) == 2 || error("wrong number of free variables for a contour plot")
        f = convert(Function, ex)
        
        xs = linspace(sort([x1,x2])...)
        ys = linspace(sort([y1,y2])...)
        zs = [float(f(x,y)) for x in xs, y in ys]
        ## Winston.contour???
        contour(xs, ys, zs, args...; kwargs...)
    end
    
    parametricplot(f::Vector{Sym}, a::Real, b::Real, args...; kwargs...) = plot(tuple(f...), a, b, args...;kwargs...)

    function add_arrow(p::Vector, v::Vector)
        n = length(p)
        p,v = map(float, p), map(float, v)
        n == 2 || error("Winston is only 2 dimensional")
        oplot([p[1], p[1] + v[1]], [p[2], p[2] + v[2]])
    end
    
    export parametricplot, contour
end

Jewel.@require PyPlot begin
    import PyPlot: plot, plot3D, contour, contour3D, plot_surface
    
    function plot(ex::Sym, a::Real, b::Real, n=250, args...; kwargs...)
        vars = get_free_symbols(ex)
        if length(vars) == 1        
            f = convert(Function, ex)
            xs = linspace(a,b, n)
            ys = map(x->float(f(x)), xs)
            plot(xs, ys, args...; kwargs...)
        elseif length(vars) == 2
            contour(ex, a, b, args...; kwargs...)
        end
    end

    ## Parametric plots use notation plot((ex1,ex2, [ex3]), t0, t1, args..., kwargs...)
    function plot(exs::(Sym...), t0::Real, t1::Real, args...; kwargs...)
        out = prepare_parametric(exs, t0, t1)
        n = length(exs)
        if n == 2
            plot(out..., args...; kwargs...)
        elseif n == 3
            plot3D(out..., args...; kwargs...)
        end
    end
    parametricplot(f::Vector{Sym}, a::Real, b::Real, args...; kwargs...) = plot(tuple(f...), a, b, args...;kwargs...)
                                                          
    ## quiver ,,,http://matplotlib.org/examples/pylab_examples/quiver_demo.html
    function vectorplot(f::Vector{Sym},
                    x1::Real=-5.0, x2::Real=5.0,
                    y1::Real=-5.0, y2::Real=5.0,
                    nx::Int=25, ny::Int=25, args...; kwargs...)

        length(f) == 2 || throw(DimensionMismatch("vector of symbolic objects must have length 2"))
        for ex in f
            nvars = length(get_free_symbols(ex))
            nvars == 2 || throw(DimensionMismatch("Expression has $nvars, expecting 2 for a quiver plot"))
        end

        f1 = (x,y) -> float(convert(Function, f[1])(x,y))
        f2 = (x,y) -> float(convert(Function, f[2])(x,y))

        xs, ys = linspace(x1, x2, nx), linspace(y1, y2, ny)

        us = [f1(x,y) for x in xs, y in ys]
        vs = [f2(x,y) for x in xs, y in ys]

        quiver(xs, ys, us, vs, args...; kwargs...)
    end
        
    function contour(ex::Sym, x1,x2, y1, y2, args...; kwargs...)
         xs = linspace(sort([x1,x2])...)
         ys = linspace(sort([y1,y2])...)
         f = convert(Function, ex)
         zs = [float(f(x,y)) for x in xs, y in ys]
         PyPlot.contour(xs, ys, zs, args...; kwargs...)
    end
    
    function contour3D(ex::Sym, x1,x2, y1, y2, args...; kwargs...)
         xs = linspace(sort([x1,x2])...)
         ys = linspace(sort([y1,y2])...)
         f = convert(Function, ex)
         zs = [float(f(x,y)) for x in xs, y in ys]
         PyPlot.contour3D(xs, ys, zs, args...; kwargs...)
    end

    function plot_surface(ex::Sym, x1,x2, y1, y2, n=250,  args...; kwargs...)
        nvars = length(get_free_symbols(ex))
        nvars == 2 || throw(DimensionMismatch("Expression has $nvars, expecting 2 for a surface plot"))
        xs = linspace(sort([x1,x2])..., n)
        ys = linspace(sort([y1,y2])..., n)
        f = convert(Function, ex)
        zs = [float(f(x,y)) for x in xs, y in ys]
        PyPlot.plot_surface(xs, ys, zs, args...; kwargs...)
    end

    function add_arrow(p::Vector, v::Vector, args...; kwargs...)
       n = length(p)
       if n == 2
         arrow(p..., v...; kwargs...)
       elseif n==3
         out = [hcat(p,p+v)'[:,i] for i in 1:n]
         plot3D(out..., args...; kwargs...)
       end
     end

    ## SymPy.plotting also implements things

@doc  """

The SymPy Python module implements many plotting interfaces and
displays them with matplotlib.  We refer to
http://docs.sympy.org/latest/modules/plotting.html for the
details. Here we export the main functionality that is not otherwise
given.

    """ ->
    plot_implicit(ex, args...; kwargs...) = sympy.plotting[:plot_implicit](ex.x, project(args)...;  [(k,project(v)) for (k,v) in kwargs]...)
    
    plot_parametric(ex1, ex2, args...; kwargs...) = sympy.plotting[:plot_implicit](ex1.x, ex2.x, project(args)...;  [(k,project(v)) for (k,v) in kwargs]...)

    ## NOT plot3D which is a PyPlot interface...
    plot3d(ex, args...; kwargs...) = sympy.plotting[:plot3d](ex.x, project(args)...;  [(k,project(v)) for (k,v) in kwargs]...)

    plot3d_parametric_line(ex1, ex2, ex3, args...; kwargs...) = sympy.plotting[:plot_implicit](ex1.x, ex2.x, ex3.x, project(args)...;  [(k,project(v)) for (k,v) in kwargs]...)

    plot3d_parametric_surface(ex1, ex2, ex3, args...; kwargs...) = sympy.plotting[:plot3d_parametric_surface](ex1.x, ex2.x, ex3.x, project(args)...;  [(k,project(v)) for (k,v) in kwargs]...)
    
    export parametricplot, vectorplot, add_arrow
    
    export plot_implicit, plot_parametric, plot3d, plot3d_parametric_line, plot3d_parametric_surface
end


Jewel.@require Gadfly begin
    import Gadfly: plot

    function plot(ex::Sym, a::Real, b::Real, args...; kwargs...)
        vars = get_free_symbols(ex)
        if length(vars) == 1        
            f = convert(Function, ex)
            plot(x -> float(f(x)), a, b, args...; kwargs...)
        elseif length(vars) == 2
            contour(ex, a, b, args...; kwargs...)
        end
    end
    
    ## Parametric plots use notation plot((ex1,ex2, [ex3]), t0, t1, args..., kwargs...)
    function plot(exs::(Sym...), t0::Real, t1::Real, args...; kwargs...)
        out = prepare_parametric(exs, t0, t1)
        n = length(exs)
        if n == 2
            plot(x=out[1],y=out[2], args...; kwargs...)
        elseif n == 3
            error("No 3D plotting in Gadfly")
        end
    end
    parametricplot(f::Vector{Sym}, a::Real, b::Real, args...; kwargs...) = plot(tuple(f...), a, b, args...;kwargs...)

    function contour(ex::Sym, x1::Real,x2::Real, y1::Real, y2::Real, args...; kwargs...)
        f = convert(Function, ex)
        Gadfly.plot((x,y) -> float(f(x,y)), x1, x2, y1, y2, args...; kwargs...)
    end
end
