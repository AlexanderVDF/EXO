#!/usr/bin/env python3
"""Test PyTorch ROCm GPU detection in WSL2."""
import sys

try:
    import torch
    print(f"PyTorch version: {torch.__version__}")
    print(f"CUDA available: {torch.cuda.is_available()}")
    print(f"CUDA device count: {torch.cuda.device_count()}")
    hip_version = getattr(torch.version, "hip", None)
    print(f"ROCm HIP version: {hip_version or 'N/A'}")
    if torch.cuda.is_available():
        for i in range(torch.cuda.device_count()):
            print(f"  Device {i}: {torch.cuda.get_device_name(i)}")
            props = torch.cuda.get_device_properties(i)
            print(f"    Memory: {props.total_mem / 1e9:.1f} GB")
            print(f"    GCN Arch: {props.gcnArchName if hasattr(props, 'gcnArchName') else 'N/A'}")
        # Quick GPU test
        t = torch.randn(1000, 1000, device="cuda")
        r = torch.mm(t, t)
        print(f"  GPU matmul test: OK ({r.shape})")
    else:
        print("No GPU detected via ROCm/HIP")
        print("Trying DirectML...")
        try:
            import torch_directml
            dml = torch_directml.device()
            print(f"  DirectML available: {torch_directml.is_available()}")
            print(f"  DirectML device: {dml}")
        except ImportError:
            print("  torch_directml not installed")
except Exception as e:
    print(f"ERROR: {e}")
    import traceback
    traceback.print_exc()
