defmodule HullSTL.STL do

  def render_stl([last, triangles]) do
     IO.puts("solid hull")
     triangles
     |> Enum.map(fn t -> _render_triangle(t) end)
     IO.puts("endsolid hull")
  end

  defp _render_triangle(t) do
         IO.puts("  facet normal #{_point_to_string(t.normal)}")
         IO.puts("    outer loop")
         {p1, p2, p3} = t.triangle 
         IO.puts("      vertex #{_point_to_string(p1)}")
         IO.puts("      vertex #{_point_to_string(p2)}")
         IO.puts("      vertex #{_point_to_string(p3)}")
         IO.puts("    endloop")
         IO.puts("  endfacet")
  end

  defp _point_to_string({x,y,z}) do 
    "#{String.trim(to_string(:io_lib.format('~e ~n',[x])))} " <>
    "#{String.trim(to_string(:io_lib.format('~e ~n',[y])))} " <>
    "#{String.trim(to_string(:io_lib.format('~e ~n',[z])))}" 
  end 

end
