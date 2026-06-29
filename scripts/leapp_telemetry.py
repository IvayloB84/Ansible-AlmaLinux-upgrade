#!/usr/bin/env python3
import json
import os
import sys

def compile_metrics():
    path = "/var/log/leapp/leapp-report.json"
    if not os.path.exists(path):
        print(f"ERROR: Target report dataset missing at {path}")
        sys.exit(1)
        
    with open(path, "r") as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError:
            print("ERROR: Corrupted JSON data matrix encountered.")
            sys.exit(1)
            
    entries = data.get("entries", [])
    
    inhibitors = sum(1 for e in entries if "inhibitor" in e.get("groups", []))
    high = sum(1 for e in entries if e.get("severity") == "high" and "inhibitor" not in e.get("groups", []))
    medium = sum(1 for e in entries if e.get("severity") == "medium")
    low_info = sum(1 for e in entries if e.get("severity") in ["low", "info"])
    
    print("\n" + "="*60)
    print("          LEAPP PRE-UPGRADE ANALYSIS AUDIT MATRIX")
    print("="*60)
    print(f"  CRITICAL INHIBITORS (HARD BLOCKERS) : {inhibitors}")
    print(f"  HIGH RISK FACTORS (WARNINGS)       : {high}")
    print(f"  MEDIUM RISK FACTORS                : {medium}")
    print(f"  LOW/INFO RISK FACTORS              : {low_info}")
    print("="*60 + "\n")

if __name__ == "__main__":
    compile_metrics()
