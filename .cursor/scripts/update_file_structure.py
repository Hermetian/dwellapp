import os
import sys
import datetime
import subprocess

# Set up paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = SCRIPT_DIR
STRUCTURE_FILE = os.path.join(OUTPUT_DIR, "file_structure.md")

def update_file_structure():
    # Get current date and time
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    
    # Get project root (two levels up from script directory)
    project_root = os.path.dirname(os.path.dirname(SCRIPT_DIR))
    
    # Change to project root
    os.chdir(project_root)
    
    # Run tree command
    try:
        structure = subprocess.run(
            ["tree", "-L", "5", "-I", "node_modules|.git|.build|Dwell.xcodeproj|*.xcodeproj|.DS_Store|*.generated.swift|Pods"],
            capture_output=True,
            text=True
        ).stdout
    except:
        structure = "Error: 'tree' command not found. Please install it using 'brew install tree'"
    
    # Write to file_structure.md
    with open(STRUCTURE_FILE, "w") as f:
        f.write(f"# DwellApp Project Structure\n\n")
        f.write(f"Generated on: {now}\n\n")
        f.write("```\n")
        f.write(structure)
        f.write("```\n\n")
        
        # Add section for important directories
        f.write("## Key Directories\n\n")
        
        key_dirs = {
            "Sources/Views": "SwiftUI views for the application UI",
            "Sources/ViewModels": "View models following MVVM pattern",
            "Sources/Models": "Data models and entities",
            "Sources/Services": "Business logic and data services",
            "Sources/FirebaseWrapper": "Firebase integration services",
            ".cursor": "Project configuration and automation scripts"
        }
        
        for dir_name, description in key_dirs.items():
            f.write(f"- `{dir_name}/`: {description}\n")
        
        # Print success message to stdout
        print(f"\nFile structure updated in {STRUCTURE_FILE}")
        print("Key directories documented with descriptions")

if __name__ == "__main__":
    update_file_structure() 