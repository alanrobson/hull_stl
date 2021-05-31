defmodule HullSTL.Geometry do

  import Graphmath

  # dimensions in meters
  @hboh 1.5 # half beam of hull at widest
  @x_steps 20 # number of buttocks
  @rib_spacing 5 # number of stations between transverse re-enforcement centers
  @stringer_spacing 20 # number of buttocks between fore-and-aft re-enforcements
  @stiffener_width 2 # a stiffener is a rib or a stringer
  @stiffener_thickness 0.1 # total hull thickness at reenforcement point
  @ordinary_thickness 0.01 # normal scantling thickness
  @x_power 1.5 # profile is y = x^@x_power as a simple start

  defp section(station, origin, thickness_with_frames) do
    {_,_,z} = origin
    # steps in the x direction - across the beam 
    # from where station crosses the centerline to where it meets the sheer 
    # each step is a "buttock"
    0..@x_steps
    |> Enum.map(fn i -> _step_to_x(i, origin) end)
    |> Enum.map(fn x -> _calc_section(x, station, origin) end) 
    # co-ordinates in the x(beam), y(freeboard), z(length) directions
  end

  def start_triangles(current) do
      1..@x_steps
      |> Enum.flat_map(fn i -> _start_triangle_faces(i, current) end) 
      # Alan |> Enum.map(fn i ->  %{normal: _triangle_to_vectors(i) |> _cross(), triangle: i} end) 
  end 

  def triangles([last, triangles], current) do
      0..@x_steps
      |> Enum.flat_map(fn i -> _face_triangles(i, last, current) end) 
      #Alan |> Enum.map(fn i ->  %{normal: _triangle_to_vectors(i) |> _cross(), triangle: i} end) 
  end 

  # define the hull section to be swept along the line y = f(x)
  # Basic design assumption is that the section is constant and independent of z
  defp _calc_y(x) do
    :math.pow(x,@x_power)
  end

  defp _normal(x) do
    up=Vec3.create(1.0, @x_power * x, 0.0)
    forward=Vec3.create(0.0, 0.0, 1.0)
    Vec3.cross(up, forward) |> Vec3.normalize()
  end

  # define the fore-aft line to sweep the origin of the section along
  defp _origin(z) do
    Vec3.create(0.0, 0.0, z)
    # the line must curve in the Y (plan plane toward the centerline) direction toward the bow 
    # to keep the stringers sane rather than rise to meet the sheer
  end

  # define the sheer line
  defp _sheer(z) do
    Vec3.create(@hboh, _calc_y(@hboh), z)
  end

  #define the scantlings (hull skin thickness) including re-enforcments (stringers / ribs)
  defp _thickness(spacing, i) do
    if (rem(i, spacing) >= (spacing - @stiffener_width)) do
      @stiffener_thickness
    else
      @ordinary_thickness
    end
  end

  defp _step_to_x(i,station) do
    # want @x_steps equal steps (buttocks) from origin to sheer
    {x_interval,_,_}  = Vec3.subtract(_sheer(station), _origin(station))
    step_size = x_interval / @x_steps
    {i, i * step_size}
  end

  defp _calc_section({buttock, x}, station, origin) do
    thickness = max(_thickness(@stringer_spacing, buttock), _thickness(@rib_spacing, station))
    y = _calc_y(x)
    normal = _normal(x)
    %{station: station,
      buttock: buttock, 
      normal: normal,
      thickness: thickness,
      outer: Vec3.create(x, y, 0.0) |> Vec3.add(origin),
      offset: Vec3.scale(normal, thickness)
    }
  end


  defp _triangle_to_vectors({{x0,y0,z0}, {x1,y1,z1}, {x2,y2,z2}}) do
    {{x1 - x0, y1 - y0, z1 - z0}, {x2 - x0, y2 - y0, z2 - z0}}
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
