import Base: writemime

# HTML utils

using .DOM

fade(x) = span(".fade", x)

# Text

function displayinline(t::Text)
  lines = split(string(t), "\n")
  Collapsible(span(".text", lines[1]),
              span(".text", join(lines[2:end], "\n")))
end

# Tables

type Table{T}
  class::ASCIIString
  data::AbstractMatrix{T}
end

Table(data::AbstractMatrix) = Table("", data)

const MAX_CELLS = 500

function getsize(h, w, maxcells)
  (h == 0 || w == 0) && return 0, 0
  swap = false
  w > h && ((w, h, swap) = (h, w, true))
  h = min(maxcells ÷ w, h)
  h ≥ w ?
    (swap ? (w, h) : (h, w)) :
    (ifloor(sqrt(maxcells)), ifloor(sqrt(maxcells)))
end

function Base.writemime(io::IO, m::MIME"text/html", table::Table)
  println(io, """<table class="$(table.class)">""")
  h, w = size(table.data)
  (h == 0 || w == 0) && @goto none
  h′, w′ = getsize(h, w, MAX_CELLS)
  for i = (h′ == h ? (1:h′) : [1:(h′÷2), h-(h′÷2)+1:h])
    println(io, """<tr>""")
    for j = (w′ == w ? (1:w′) : [1:(w′÷2), w-(w′÷2)+1:w])
      println(io, """<td>""")
      if isdefined(table.data, i, j)
        item = applydisplayinline(table.data[i, j])
        writemime(io, bestmime(item), item)
      else
        print(io, "#undef")
      end
      println(io, """</td>""")

      w > w′ && j == (w′÷2) && println(io, """<td>⋯</td>""")
    end
    println(io, """</tr>""")

    h > h′ && i == (h′÷2) && println(io, "<tr>","<td>⋮</td>"^(w≤w′?w:w′+1),"</tr>")
  end
  @label none
  println(io, """</table>""")
end

# Nothing

displayinline(::Nothing) = Text("✓")

# Floats

# round n to k significant digits
function round_sig{T<:FloatingPoint}(n::T, k::Integer)
    s = n < 0 ? -1 : 1
    n = abs(n)
    n == 0 && return zero(T)
    n == Inf && return s*inf(T)
    isnan(n) && return nan(T)
    e = floor(log10(n))
    if e - k + 1 > 0 # for numeric stability...
        s *= int(n*10^(k-e-1))*10.0^(e-k+1)
    else
        s *= int(n*10^(k-e-1))/10.0^-(e-k+1)
    end
    return convert(T, s)
end

# round to three significant digits after the decimal point and return a string
function round3(n::FloatingPoint)
    res = n < 0 ? "-" : ""
    n = abs(n)
    n == Inf && return res*string(n)
    isnan(n) && return string(NaN)
    s = split(string(n), '.')[1]
    k1 = length(match(r"[1-9]*", s).match)
    k2 = length(match(r"[0-9]*", s).match)
    tmp = split(string(round_sig(n, k1+3)), 'e')
    if length(tmp[1]) < k2+4
        if length(tmp) == 1
            res *= tmp[1]*"0"^(k2+4-length(string(tmp[1])))
        else
            res *= tmp[1]*"0"^(k2+4-length(string(tmp[1])))*"e"*tmp[2]
        end
    else
        res *= tmp[1] * (length(tmp)>1 ? "e"*tmp[2] : "")
    end
    return res
end

function writemime(io::IO, m::MIME"text/html", x::FloatingPoint)
  print(io, """<span class="float" title="$(string(x))">""")
  print(io, round3(x))
  print(io, """</span>""")
end

displayinline!(x::FloatingPoint, opts) =
  showresult(stringmime("text/html", x), opts, html=true)

# Functions

name(f::Function) =
  isgeneric(f) ? string(f.env.name) :
  isdefined(f, :env) && isa(f.env,Symbol) ? string(f.env) :
  "λ"

displayinline(f::Function) =
  isgeneric(f) ?
    Collapsible(strong(name(f)), methods(f)) :
    Text(name(f))

# Arrays

sizestr(a::AbstractArray) = join(size(a), "×")

displayinline(a::Matrix) =
  Collapsible(span(strong("Matrix "), fade("$(eltype(a)), $(sizestr(a))")),
              Table("array", a))

function copytranspose(xs::Vector)
  result = similar(xs, length(xs), 1)
  for i = 1:length(xs)
    isdefined(xs, i) && (result[i] = xs[i])
  end
  return result
end

displayinline(a::Vector, t = "Vector") =
  Collapsible(span(strong(t), fade(" $(eltype(a)), $(length(a))")),
              Table("array", copytranspose(a)))

displayinline(s::Set) = displayinline(collect(s), "Set")

displayinline(d::Dict) =
  Collapsible(span(strong("Dictionary "), fade("$(eltype(d)[1]) → $(eltype(d)[2]), $(length(d))")),
              HTML() do io
                println(io, """<table class="array">""")
                kv = collect(d)
                for i = 1:(min(length(kv), MAX_CELLS÷2))
                  print(io, "<tr><td>")
                  item = displayinline(kv[i][1])
                  writemime(io, bestmime(item), item)
                  print(io, "</td><td>")
                  item = displayinline(kv[i][2])
                  writemime(io, bestmime(item), item)
                  print(io, "</td></tr>")
                end
                length(kv) ≥ MAX_CELLS÷2 && println(io, """<td>⋮</td><td>⋮</td>""")
                println(io, """</table>""")
              end)

# Others

import Jewel: @require

# Data Frames

@require DataFrames begin
  displayinline(f::DataFrames.DataFrame) =
    isempty(f) ? Collapsible(span(strong("DataFrame "), fade("Empty"))) :
      Collapsible(span(strong("DataFrame "), fade("($(join(names(f), ", "))), $(size(f,1))")),
                  Table("data-frame", vcat(map(s->HTML(string(s)), names(f))',
                                           DataFrames.array(f))))
end

# Colors

@require Color begin
  displayinline(c::Color.ColourValue) =
    Collapsible(span(strong(@d(:style => "color: #$(Color.hex(c))"),
                            "#$(Color.hex(c)) "),
                     fade(string(c))),
                tohtml(MIME"image/svg+xml"(), c))

  displayinline{C<:Color.ColourValue}(cs::VecOrMat{C}) = tohtml(MIME"image/svg+xml"(), cs)
end

# Gadfly

@require Gadfly begin
  displayinline(p::Gadfly.Plot) = div(p, style = "background: white")
end

# PyPlot

@require PyPlot begin
  try
    PyPlot.pygui(true)
  catch e
    warn("PyPlot is set to display in the console")
  end
end

# Images

@require Images begin
  displayinline{T,N,A}(img::Images.Image{T,N,A}) =
    Collapsible(HTML("""$(strong("Image")) <span class="fade">$(sizestr(img)), $T</span>"""),
                HTML(applydisplayinline(img.properties),tohtml(MIME"image/png"(), img)))
end

# Expressions

fixsyms(x) = x
fixsyms(x::Symbol) = @> x string replace(r"#", "_") symbol
fixsyms(ex::Expr) = Expr(ex.head, map(fixsyms, ex.args)...)

function displayinline(x::Expr)
  rep = stringmime(MIME"text/plain"(), x |> fixsyms)
  lines = split(rep, "\n")
  html = span(".code.text", @d("data-lang" => "julia2"), rep)
  length(lines) == 1 && length(lines[1]) ≤ 50 ?
    Collapsible(html) :
    Collapsible(strong("Julia Code"), html)
end

# Profile tree

function toabspath(file)
  isabspath(file) && file
  path = basepath(file)
  return path == nothing ? file : path
end

@require Jewel.ProfileView begin
  function displayinline!(tree::Jewel.ProfileView.ProfileTree, opts)
    raise(opts[:editor], "julia.profile-result",
          @d("value" => stringmime("text/html", tree),
             "bounds" => opts[:bounds],
             "lines" => [@d(:file => toabspath(li.file),
                            :line => li.line,
                            :percent => p) for (li, p) in Jewel.ProfileView.fetch() |> Jewel.ProfileView.flatlines]))
  end
end
