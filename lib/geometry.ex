defmodule HullSTL.Geometry do

  alias Graphmath.Vec3, as: V

  # dimensions in meters
  @hboh 1.5 # half beam of hull at widest
  @x_step_size  0.05
  @x_steps trunc(@hboh / @x_step_size) # number of buttocks
  @rib_spacing 20 # number of stations between transverse re-enforcement centers
  @stringer_spacing 10 # number of buttocks between fore-and-aft re-enforcements
  @stiffener_width 2 # a stiffener is a rib or a stringer
  @stiffener_thickness 0.1 # total hull thickness at reenforcement point
  @ordinary_thickness 0.01 # normal scantling thickness
  @x_power 1.5 # profile is y = x^@x_power as a simple start

  def section(station, z_step_size) do
    0..@x_steps
    |> Enum.map(fn i ->
        thickness = max(_thickness(@stringer_spacing, i), _thickness(@rib_spacing, station))
        x = (i * @x_step_size)
        y = _calc_y(x)
        normal = _normal(x)
        offset =  V.scale(normal, thickness)
        outer = V.create(x, y, 0.0) |> V.add(_origin(station * z_step_size))
        %{
          station: station,
          buttock: i, 
          normal: normal,
          thickness: thickness,
          outer: outer,
          inner: V.add(outer, offset)
        } 
        end)
  end

  def start_triangles(current) do
      1..@x_steps
      |> Enum.flat_map(fn i -> _start_triangle_faces(i, current) end) 
      |> Enum.map(fn i ->  %{normal: _triangle_to_normal(i), triangle: i} end) 
  end 

  def triangles([last, _], current) do
      0..@x_steps
      |> Enum.flat_map(fn i -> _face_triangles(i, last, current) end) 
      |> Enum.map(fn i ->  %{normal: _triangle_to_normal(i), triangle: i} end) 
  end 
  
  # define the fore-aft line to sweep the origin of the section along
  defp _origin(z) do
    V.create(0.0, 0.0, z)
    # the line must curve in the Y (plan plane toward the centerline) direction toward the bow 
    # to keep the stringers sane rather than rise to meet the sheer
  end

  # define the sheer line
  defp _sheer(z) do
    V.create(@hboh, _calc_y(@hboh), z)
  end

  # define the hull section to be swept along the line y = f(x)
  # Basic design assumption is that the section is constant and independent of z
  defp _calc_y(x) do
    :math.pow(x,@x_power)
  end

  defp _normal(x) do
    up=V.create(1.0, @x_power * x, 0.0)
    forward=V.create(0.0, 0.0, 1.0)
    V.cross(forward, up) |> V.normalize()
  end

  #define the scantlings (hull skin thickness) including re-enforcments (stringers / ribs)
  defp _thickness(spacing, i) do
    if (rem(i, spacing) >= (spacing - @stiffener_width)) do
      @stiffener_thickness
    else
      @ordinary_thickness
    end
  end

  defp _step_to_x(i,{_,_,station_z}) do
    # want @x_steps equal steps (buttocks) from origin to sheer
    IO.inspect(:stderr, _sheer(station_z), [])
    IO.inspect(:stderr, _origin(station_z), [])
    {x_interval,_,_}  = V.subtract(_sheer(station_z), _origin(station_z))
    step_size = x_interval / @x_steps
    {i, i * step_size}
  end



  defp _triangle_to_normal({{x0,y0,z0}, {x1,y1,z1}, {x2,y2,z2}}) do
    V.cross(V.create(x1 - x0, y1 - y0, z1 - z0), V.create(x2 - x0, y2 - y0, z2 - z0)) |> V.normalize()
  end

  defp _start_triangle_faces(i, current) do
    point = Enum.at(current, i)
    lower_point = Enum.at(current, i - 1)
    [{point.inner, point.outer, lower_point.outer}, {lower_point.outer, lower_point.inner, point.inner}] 
  end

  defp _face_triangles(0, last, current) do
    point = Enum.at(current, 0)
    aft_point = Enum.at(last, 0)
    [{point.inner, point.outer, aft_point.outer}, {aft_point.outer, aft_point.inner, point.inner}] 
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

    if (@x_steps == i) do
      outer ++ inner ++ [{point.inner, point.outer, aft_point.outer}, {aft_point.outer, aft_point.inner, point.inner}] 
    else
      outer ++ inner
    end
  end
end
