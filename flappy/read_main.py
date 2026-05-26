import sys
from godot_mcp import GodotMCP

def main():
    godot = GodotMCP()
    print("--- Reading res://scenes/main.gd ---")
    script_content = godot.read_script("res://scenes/main.gd")
    if "error" in script_content:
        print(f"Error: {script_content['error']}")
    else:
        # The tool returns content in a 'content' list
        content = script_content['content'][0]['text']
        print(content)

if __name__ == "__main__":
    main()
