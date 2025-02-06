import sys
import re
import json
import datetime
import subprocess
from collections import Counter
import os

# Set up paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = SCRIPT_DIR
BUGFIXES_FILE = os.path.join(OUTPUT_DIR, "bugfixes.md")
SUMMARY_FILE = os.path.join(OUTPUT_DIR, "last_session_summary.md")

def extract_error_context(context, error_match, window=3):
    """Extract lines around an error for context."""
    lines = context.split('\n')
    for i, line in enumerate(lines):
        if error_match in line:
            start = max(0, i - window)
            end = min(len(lines), i + window + 1)
            return '\n'.join(lines[start:end])
    return error_match

def find_solution_for_error(context, error, window=5):
    """Find the solution that resolved this error."""
    lines = context.split('\n')
    error_indices = [i for i, line in enumerate(lines) if error in line]
    
    for error_idx in error_indices:
        # Look for positive responses after this error
        for i in range(error_idx + 1, min(len(lines), error_idx + window)):
            line = lines[i].lower()
            if any(phrase in line for phrase in ['that worked', 'fixed', 'solved', 'resolved']):
                # Look back for the last code change or action
                for j in range(i-1, error_idx, -1):
                    if 'edit_file' in lines[j] or 'run_terminal_cmd' in lines[j]:
                        return '\n'.join(lines[j:i+1])
    return None

def get_conversation_context():
    """Get the full conversation context."""
    # First try to get context from environment variable
    cursor_context = os.getenv('CURSOR_CONTEXT')
    if cursor_context:
        return cursor_context
        
    try:
        # Try to read from stdin without blocking
        import select
        if select.select([sys.stdin], [], [], 0.0)[0]:
            return sys.stdin.read()
    except:
        pass
    
    # If no stdin, try to read from conversation history
    try:
        with open('.conversation_history', 'r') as f:
            return f.read()
    except:
        pass
    
    return "No conversation context found"

def summarize_session():
    # Get full context from cursor agent
    context = get_conversation_context()
    
    # Error and Frustration Analysis
    errors = re.findall(r"(?:error|exception|failed|failure)[^\n.]*[\n.][^\n.]*", context, re.I)
    frustration = re.findall(r"([A-Z !]{4,}|(?:damn|shit|fuck|crap))[^\n.]*", context)
    
    # Count error occurrences
    error_counter = Counter(errors)
    most_common_errors = error_counter.most_common()
    
    # Solutions and Attempts
    solutions = []
    ambiguous = []
    
    # Look for solution patterns
    solution_patterns = [
        (r"(?:that worked|fixed|solved)[^\n.]*(?:[\n.][^\n.]*){0,2}", "SOLVED"),
        (r"(?:let's try|try something|different approach)[^\n.]*(?:[\n.][^\n.]*){0,2}", "??"),
        (r"(?:this might|maybe|could try)[^\n.]*(?:[\n.][^\n.]*){0,2}", "?"),
    ]
    
    for pattern, prefix in solution_patterns:
        matches = re.findall(pattern, context, re.I)
        for match in matches:
            if prefix in ["??", "?"]:
                ambiguous.append((prefix, match))
            else:
                solutions.append(match)
    
    # Print summary to stdout
    print("\n=== Session Summary ===\n")
    print(f"Session Date: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M')}\n")
    
    if solutions:
        print("\nCompleted Changes:")
        for sol in solutions:
            print(f"✓ {sol}")
    
    if ambiguous:
        print("\nIn Progress/Attempted Changes:")
        for prefix, attempt in ambiguous:
            print(f"{prefix} {attempt}")
    
    if most_common_errors:
        print("\nOutstanding Issues:")
        for error, count in most_common_errors:
            if not find_solution_for_error(context, error):
                print(f"! {error} (occurred {count} times)")
    
    print("\nNext Steps:")
    if most_common_errors:
        print("1. Address remaining errors")
    if ambiguous:
        print("2. Follow up on attempted changes")
    print("3. Continue with planned development tasks")
    
    # Write to files in scripts directory
    with open(BUGFIXES_FILE, "a") as f:
        f.write(f"\n\n## Session {datetime.datetime.now().strftime('%Y-%m-%d %H:%M')}\n")
        
        if most_common_errors or frustration:
            f.write("\n### Issues Found\n")
            
            # Document most common errors with context and solutions
            for error, count in most_common_errors:
                f.write(f"\n#### Error (occurred {count} times):\n")
                f.write("```\n")
                f.write(extract_error_context(context, error))
                f.write("\n```\n")
                
                solution = find_solution_for_error(context, error)
                if solution:
                    f.write("\nResolution:\n```\n")
                    f.write(solution)
                    f.write("\n```\n")
                else:
                    f.write("\n⚠️ No clear resolution found\n")
            
            # Document frustration points
            if frustration:
                f.write("\n#### Frustration Points:\n")
                for f in set(frustration):
                    f.write(f"- {f[0]}\n")
        
        if solutions or ambiguous:
            f.write("\n### Solutions and Attempts:\n")
            for sol in solutions:
                f.write(f"- SOLVED: {sol}\n")
            for prefix, attempt in ambiguous:
                f.write(f"- {prefix} {attempt}\n")
    
    # Create last_session_summary.md in scripts directory
    with open(SUMMARY_FILE, "w") as f:
        f.write("# Last Session Summary\n\n")
        f.write(f"Session Date: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M')}\n\n")
        
        # Get recent file changes
        try:
            git_changes = subprocess.run(
                ["git", "diff", "--name-status"],
                capture_output=True,
                text=True
            ).stdout
            if git_changes:
                f.write("## Files Changed\n")
                f.write("```\n" + git_changes + "```\n\n")
        except:
            pass
        
        # Get current project structure
        try:
            structure = subprocess.run(
                ["tree", "-L", "2", "-I", "node_modules|.git|.build|Dwell.xcodeproj"],
                capture_output=True,
                text=True
            ).stdout
            if structure:
                f.write("## Project Structure\n")
                f.write("```\n" + structure + "```\n\n")
        except:
            pass
        
        # Document key changes and state
        f.write("## Session Overview\n")
        if solutions:
            f.write("\n### Completed Changes\n")
            for sol in solutions:
                f.write(f"- {sol}\n")
        
        if ambiguous:
            f.write("\n### In Progress/Attempted Changes\n")
            for prefix, attempt in ambiguous:
                f.write(f"- {prefix} {attempt}\n")
        
        if most_common_errors:
            f.write("\n### Outstanding Issues\n")
            for error, count in most_common_errors:
                if not find_solution_for_error(context, error):
                    f.write(f"- {error} (occurred {count} times)\n")
        
        # Add continuation hints
        f.write("\n## Next Steps\n")
        if most_common_errors:
            f.write("1. Address remaining errors\n")
        if ambiguous:
            f.write("2. Follow up on attempted changes\n")
        f.write("3. Continue with planned development tasks\n")

if __name__ == "__main__":
    summarize_session() 
