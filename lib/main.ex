defmodule HullSTL.Main do

  @loa 12
  @hboh 1.0 
  @steps 3
  @rib_spacing 10
  @stringer_spacing 10
  @ribwidth 2
  @normal_thickness 0.01
  @rib_thickness 0.05
  @centerline_x 0.0

  # define the hull section to be swept along the line
  defp _calc_y(x) do
    x * x
  end
  defp _calc_slope(x) do
    2.0 * x
  end

  # define the fore-aft line to sweep along
  defp _sweep(z) do
    {0.0, 0.0, z}
    # the line must curve in the Y (plan) direction toward the bow to keep the stringers sane
  end

  # define the sheer line
  defp _sheer(z) do
    {@hboh, _calc_y(@hboh), z}
  end

  #define the scantlings (hull thickness)
  defp thickness(spacing, i) do
    if (rem(i, spacing) >= (spacing - @ribwidth)) do
      @rib_thickness
    else
      @normal_thickness
    end
  end

  defp section(station, origin, depth) do
    {_,_,z} = origin
    0..@steps # steps in the x direction - across the beam - from where station crosses the centerline to where it meets the sheer
    |> Enum.map(fn i -> _step_to_x(i,z) end)
    |> Enum.map(fn x -> _calc_section(x, station, origin, depth) end) # co-ordinates in the x(beam), y(freeboard), z(length) directions and slope at (xy) perpendicular to z
  end

  defp _step_to_x(i,z) do
    # want n equal steps from centerline to sheer
    {sheer_x, _, _} = _sheer(z)
    interval = sheer_x - @centerline_x # overly simplistic but it will do for now
    step_size = interval / @steps
    {i, @centerline_x + (i * step_size)}
  end

  defp _calc_section({buttock, x}, station, {o_x, o_y, o_z}, depth) do
    _calc_inv_slope = fn 
        0, _, _ -> 1.0
        @steps, _, _ -> 0.0
        _, x, _ when x < 0.0001 -> 1.0
        buttock, _, slope -> -1.0 * (1.0 / slope)
    end
    total_depth = max(depth, thickness(@stringer_spacing, buttock))
    y = _calc_y(x)
    slope = _calc_slope(x)
    inv_slope = _calc_inv_slope.(buttock, x, slope)
    #IO.puts("buttock: #{buttock}, x: #{x}, slope: #{slope}, inv_slope: #{inv_slope}")
    %{station: station,
      buttock: buttock, 
      slope: slope,
      inv_slope: inv_slope,
      x: x,
      thickness: total_depth,
      outer: {x + o_x, y + o_y, o_z} ,
      inner: _inner_xy(x,y,inv_slope,total_depth, o_z)
    }
  end

  defp _inner_xy(x, y, inv_slope, hypotenuse, z) do
      # dy/dx = inv_slope
      # h^2 = dx^2 + (inv_slope * dx)^2
      # h^2 = dx^2 + (inv_slope^2 * dx^2)
      # h^2 = (1 + inv_slope^2)dx^2
      inv_slope_squared = :math.pow(inv_slope, 2)
      h_squared = :math.pow(hypotenuse,2)
      dx_squared = h_squared / (1.0 + inv_slope_squared)
      dx = :math.sqrt(dx_squared)
      dy = inv_slope * dx
      check_h = :math.sqrt(:math.pow(dx,2) + :math.pow(dy,2))
      if (inv_slope < 0.0) do
        {max(@centerline_x,x - dx), y - dy, z}
      else
        {max(@centerline_x,x - dx), y + dy, z}
      end
  end

  defp _triangles([last, triangles], current) do
      1..@steps
      |> Enum.flat_map(fn i -> _face_triangles(i, last, current) end) 
      |> Enum.map(fn i ->  %{normal: _triangle_to_vectors(i) |> _cross(), triangle: i} end) 
  end 

  defp _triangle_to_vectors({{x0,y0,z0}, {x1,y1,z1}, {x2,y2,z2}}) do
    {{x1 - x0, y1 - y0, z1 - z0}, {x2 - x0, y2 - y0, z2 - z0}}
  end

  defp _dot({ux,uy,uz}, {vx,vy,vz}) do
    ux * vx + uy * vy + uz * vz
  end

  defp _cross({{ux,uy,uz}, {vx,vy,vz}}) do
    nx = uy * vz - uz * vy
    ny = uz * vx - ux * vz
    nz = ux * vy - uy * vx
    {nx, ny, nz}
  end

  defp _face_triangles(i, last, current) do
    point = Enum.at(current, i)
    lower_point = Enum.at(current, i - 1)
    aft_point = Enum.at(last, i)
    lower_aft_point = Enum.at(last, i - 1)

    # clockwise winding
    outer = [{aft_point, point, lower_point}, {aft_point, lower_point, lower_aft_point}]
            |> Enum.map(fn {a,b,c} -> {a.outer,b.outer,c.outer} end)
    inner = [{point, aft_point, lower_aft_point}, {point, lower_aft_point, lower_point}]
            |> Enum.map(fn {a,b,c} -> {a.inner,b.inner,c.inner} end)

    outer ++ inner
   
  end

  def main(args) do
    0..2  # steps in the z direction, along the length
      |> Enum.map(fn(i) -> [i, (@loa * i)/@steps] end)
      |> Enum.map(fn([i,z]) -> [i,_sweep(z)] end)
      |> Enum.map(fn([i,origin]) -> section(i, origin, thickness(@rib_spacing, i))  end)
      |> Enum.reduce([[],[]], fn # [[last points], [triangles]]
                                   (current, [[],[]]) -> [current, []]   
                                   (current, [last, triangles]) -> [current, triangles ++ _triangles([last, triangles], current)]   
                                 end)
      |> _render_stl()
  end

  defp _render_stl([last, triangles]) do
     IO.puts("solid hull")
     triangles
     |> Enum.map(fn t -> _render_triangle(t) end)
     IO.puts("endsolid hull")
  end

  defp _render_triangle(t) do
         IO.puts("  facet normal #{_point_to_string(t.normal)}")
         IO.puts("    outer loop")
         {p1, p2, p3} = t.triangle 
         IO.puts("      vertex info #{_point_to_string(p1)}")
         IO.puts("      vertex info #{_point_to_string(p2)}")
         IO.puts("      vertex info #{_point_to_string(p3)}")
         IO.puts("    endloop")
         IO.puts("  endfacet")
  end

  defp _point_to_string({x,y,z}) do "#{x}, #{y}, #{z}" end

end
