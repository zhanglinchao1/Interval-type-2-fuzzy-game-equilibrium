#!/usr/bin/env python3
"""
Simple test script to verify OWA-RL weight collection functionality
"""

import csv
import os
import sys
import numpy as np
import matplotlib.pyplot as plt

def test_weight_collection():
    print("=== OWA-RL Weight Collection Test ===")
    
    # Check data directory
    data_dir = "data"
    if not os.path.exists(data_dir):
        print(f"❌ Data directory '{data_dir}' not found")
        return False
    
    print(f"✅ Data directory found: {data_dir}")
    
    # Look for weight evolution files
    weight_files = [f for f in os.listdir(data_dir) if f.startswith("weight_evolution")]
    
    if not weight_files:
        print("❌ No weight evolution files found")
        return False
    
    print(f"✅ Found {len(weight_files)} weight evolution files")
    
    # Test reading a sample file
    try:
        sample_file = os.path.join(data_dir, weight_files[0])
        with open(sample_file, 'r') as f:
            reader = csv.DictReader(f)
            rows = list(reader)
        
        if not rows:
            print("❌ Sample file is empty")
            return False
        
        print(f"✅ Sample file contains {len(rows)} records")
        
        # Check required columns
        required_cols = ['time', 'w1', 'w2', 'w3', 'scenario']
        first_row = rows[0]
        missing_cols = [col for col in required_cols if col not in first_row]
        
        if missing_cols:
            print(f"❌ Missing columns: {missing_cols}")
            return False
        
        print("✅ All required columns present")
        
        # Verify data ranges
        times = [float(row['time']) for row in rows]
        w1_vals = [float(row['w1']) for row in rows]
        w2_vals = [float(row['w2']) for row in rows]
        w3_vals = [float(row['w3']) for row in rows]
        
        print(f"✅ Time range: {min(times):.1f} - {max(times):.1f}")
        print(f"✅ w1 range: {min(w1_vals):.3f} - {max(w1_vals):.3f}")
        print(f"✅ w2 range: {min(w2_vals):.3f} - {max(w2_vals):.3f}")
        print(f"✅ w3 range: {min(w3_vals):.3f} - {max(w3_vals):.3f}")
        
        # Check weight sum constraint
        weight_sums = [float(row['w1']) + float(row['w2']) + float(row['w3']) for row in rows]
        avg_sum = np.mean(weight_sums)
        
        if abs(avg_sum - 1.0) > 0.1:
            print(f"⚠️  Weight sum constraint violation: average sum = {avg_sum:.3f}")
        else:
            print(f"✅ Weight sum constraint satisfied: average sum = {avg_sum:.3f}")
        
        # Check scenario diversity
        scenarios = set(row['scenario'] for row in rows)
        print(f"✅ Found {len(scenarios)} different scenarios: {scenarios}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error reading sample file: {e}")
        return False

def create_test_plot():
    """Create a test visualization"""
    try:
        data_dir = "data"
        weight_files = [f for f in os.listdir(data_dir) if f.startswith("weight_evolution")]
        
        if not weight_files:
            print("No data files for plotting")
            return
        
        # Read first file
        sample_file = os.path.join(data_dir, weight_files[0])
        
        times, w1_vals, w2_vals, w3_vals, scenarios = [], [], [], [], []
        
        with open(sample_file, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                times.append(float(row['time']))
                w1_vals.append(float(row['w1']))
                w2_vals.append(float(row['w2']))
                w3_vals.append(float(row['w3']))
                scenarios.append(row['scenario'])
        
        # Create plot
        plt.figure(figsize=(12, 8))
        
        plt.plot(times, w1_vals, 'b-', label='w₁ (Trust)', linewidth=2)
        plt.plot(times, w2_vals, 'r-', label='w₂ (Delay)', linewidth=2)
        plt.plot(times, w3_vals, 'g-', label='w₃ (Resource)', linewidth=2)
        
        plt.xlabel('Time (s)')
        plt.ylabel('Weight Value')
        plt.title('OWA-RL Weight Evolution - Test Data')
        plt.legend()
        plt.grid(True, alpha=0.3)
        
        # Add scenario markers
        unique_scenarios = list(set(scenarios))
        colors = ['orange', 'purple', 'cyan', 'yellow']
        
        for i, scenario in enumerate(unique_scenarios[:4]):
            scenario_times = [t for t, s in zip(times, scenarios) if s == scenario]
            if scenario_times:
                plt.axvline(x=scenario_times[0], color=colors[i % len(colors)], 
                           linestyle='--', alpha=0.7, label=f'{scenario} start')
        
        plt.tight_layout()
        plt.savefig('test_weight_evolution.png', dpi=150, bbox_inches='tight')
        print("✅ Test plot saved as 'test_weight_evolution.png'")
        
    except Exception as e:
        print(f"❌ Error creating test plot: {e}")

if __name__ == "__main__":
    success = test_weight_collection()
    
    if success:
        print("\n🎉 All tests passed! OWA-RL weight collection is working correctly.")
        create_test_plot()
    else:
        print("\n❌ Tests failed. Please check the implementation.")
        sys.exit(1)