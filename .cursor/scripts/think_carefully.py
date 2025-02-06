import sys
import re
import json
import datetime
import subprocess
import os

# Set up paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = SCRIPT_DIR
ANALYSIS_FILE = os.path.join(OUTPUT_DIR, "careful_analysis.md")

def think_carefully():
    context = sys.stdin.read()
    recent_messages = re.findall(r"<user_query>[^<]*</user_query>", context)
    current_task = recent_messages[-1].replace("<user_query>", "").replace("</user_query>", "") if recent_messages else ""
    code_snippets = re.findall(r"```[^`]*```", context)
    file_refs = re.findall(r"[\w-]+\.[\\w]+", context)
    requirements = re.findall(r"(?:must|should|need to|has to|requires)[^\n.]*", context, re.I)
    
    # Analyze project structure
    project_structure = {}
    try:
        result = subprocess.run(["ls", "-R", "Sources"], capture_output=True, text=True)
        if result.returncode == 0:
            project_structure["source_files"] = result.stdout
    except:
        pass
    
    with open(ANALYSIS_FILE, "w") as f:
        f.write(f"# Careful Analysis - {datetime.datetime.now().strftime('%Y-%m-%d %H:%M')}\n\n")
        f.write("## Current Task\n")
        f.write(f"{current_task}\n\n")
        f.write("## Context Analysis\n")
        if project_structure:
            f.write("### Project Structure\n")
            f.write("```\n" + project_structure.get("source_files", "") + "```\n\n")
        if code_snippets:
            f.write(f"### Code Context\n- {len(code_snippets)} code snippets found\n")
        if file_refs:
            f.write("### Referenced Files\n")
            for file in sorted(set(file_refs)):
                f.write(f"- {file}\n")
        f.write("\n## Systematic Approach\n")
        f.write("1. Understand the Context\n")
        f.write("   - Review all referenced files\n")
        f.write("   - Identify dependencies\n")
        f.write("   - Note potential side effects\n")
        f.write("2. Consider Edge Cases\n")
        f.write("   - Input validation\n")
        f.write("   - Error handling\n")
        f.write("   - Resource management\n")
        f.write("3. Evaluate Impact\n")
        f.write("   - Performance implications\n")
        f.write("   - Security considerations\n")
        f.write("   - Maintainability aspects\n")
        f.write("4. Plan Implementation\n")
        f.write("   - Break down into steps\n")
        f.write("   - Identify potential risks\n")
        f.write("   - Consider alternatives\n")
        f.write("\n## Key Considerations\n")
        f.write("- Have all requirements been addressed?\n")
        f.write("- What could go wrong?\n")
        f.write("- Are there simpler alternatives?\n")
        f.write("- What are the trade-offs?\n")
        f.write("- How will this scale?\n")

if __name__ == "__main__":
    think_carefully() 