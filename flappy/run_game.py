from godot_mcp import GodotMCP

def main():
    godot = GodotMCP()
    print("Running project...")
    result = godot.run_project()
    print(result)

if __name__ == "__main__":
    main()
