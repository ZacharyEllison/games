import sys
from godot_mcp import GodotMCP

def main():
    godot = GodotMCP()
    # We want a curve that starts at 3.0 and ends at 1.0
    # Curve points are (position, amplitude) where position is 0-1
    # In Godot 4, Curve points are Vector2(position, value)
    
    code = """
var curve = Curve.new()
curve.add_point(Vector2(0.0, 3.0))
curve.add_point(Vector2(1.0, 1.0))
if not DirAccess.dir_exists_absolute("res://curves"):
	DirAccess.make_dir_absolute("res://curves")
var error = ResourceSaver.save(curve, "res://curves/pipe_interval_curve.tres")
if error == OK:
	print("Successfully saved curve to res://curves/pipe_interval_curve.tres")
else:
	print("Failed to save curve, error code: ", error)
"""
    print("Executing script to create curve...")
    result = godot.execute_editor_script(code)
    print(result)

if __name__ == "__main__":
    main()
