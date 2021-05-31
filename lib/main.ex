defmodule HullSTL.Main do
  alias HullSTL.Geometry, as: Geometry
  alias HullSTL.STL, as: STL
  @z_steps 100 # number of stations
  @loa 12.0 # length overall

  def main(args) do
    0..@z_steps  # steps in the z direction, along the length
      |> Enum.map(fn(station) -> [station, (@loa * station)/@z_steps] end)
      |> Enum.map(fn([station,z]) -> [station,Geometry.sweep(z)] end)
      |> Enum.map(fn([station,origin]) -> Geometry.section(station, origin, Geometry.thickness(@rib_spacing, station))  end)
      |> Enum.reduce([[],[]], fn # [[last points], [triangles]]
        (current, [[],[]]) -> [current, Geometry.start_triangles(current)]   
        (current, [last, triangles]) -> [current, triangles ++ Geometry.triangles([last, triangles], current)] end)
      |> STL.render_stl()
  end

end
