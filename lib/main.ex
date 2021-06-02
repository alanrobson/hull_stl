defmodule HullSTL.Main do
  alias HullSTL.Geometry, as: Geometry
  alias HullSTL.STL, as: STL
  @z_step_size 0.05 # number of stations
  @loa 12.0 # length overall
  @z_steps trunc(@loa / @z_step_size)

  def main(_args) do
    0..@z_steps  # steps in the z direction, along the length
      |> Enum.map(&Geometry.section(&1, @z_step_size))
      |> Enum.reduce([[],[]], fn # [[last points], [triangles]]
        (current, [[],[]]) -> [current, Geometry.start_triangles(current)]   
        (current, [last, triangles]) -> [current, triangles ++ Geometry.triangles([last, triangles], current)] end)
      |> STL.render_stl()
  end

end
