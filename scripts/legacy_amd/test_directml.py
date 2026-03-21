"""
test_directml.py — Verify ONNX Runtime DirectML uses AMD GPU

Run:
  .venv_stt_tts\\Scripts\\python.exe scripts/test_directml.py

Expected: DmlExecutionProvider active, GPU MatMul benchmark.
"""

import sys
import time


def main():
    print("=" * 60)
    print("  DirectML GPU Verification Test")
    print("=" * 60)

    # ── 1. ONNX Runtime + DirectML ──────────────────────────────────
    try:
        import onnxruntime as ort
    except ImportError:
        print("\nERROR: onnxruntime not installed")
        print("  Fix: pip install onnxruntime-directml")
        sys.exit(1)

    print(f"\nONNX Runtime  : {ort.__version__}")
    providers = ort.get_available_providers()
    print(f"Providers     : {providers}")

    if "DmlExecutionProvider" not in providers:
        print("\nERROR: DmlExecutionProvider NOT available!")
        print("  Fix: pip uninstall onnxruntime -y")
        print("       pip install onnxruntime-directml")
        sys.exit(1)

    print("DmlProvider   : OK")

    # ── 2. Build a simple MatMul ONNX model ─────────────────────────
    try:
        import onnx
        from onnx import helper, TensorProto
    except ImportError:
        print("\nWARNING: 'onnx' package not installed, skipping GPU benchmark")
        print("  Fix: pip install onnx")
        _check_pytorch()
        return

    import numpy as np
    import os
    import tempfile

    A = helper.make_tensor_value_info("A", TensorProto.FLOAT, [1024, 1024])
    B = helper.make_tensor_value_info("B", TensorProto.FLOAT, [1024, 1024])
    C = helper.make_tensor_value_info("C", TensorProto.FLOAT, [1024, 1024])

    graph = helper.make_graph(
        [helper.make_node("MatMul", ["A", "B"], ["C"])],
        "directml_test",
        [A, B],
        [C],
    )
    model = helper.make_model(
        graph, opset_imports=[helper.make_opsetid("", 17)]
    )

    tmp = os.path.join(tempfile.gettempdir(), "exo_directml_test.onnx")
    onnx.save(model, tmp)

    # ── 3. Run on DirectML ──────────────────────────────────────────
    sess_dml = ort.InferenceSession(
        tmp, providers=["DmlExecutionProvider", "CPUExecutionProvider"]
    )
    active_dml = sess_dml.get_providers()
    print(f"\nDirectML session providers: {active_dml}")

    a = np.random.randn(1024, 1024).astype(np.float32)
    b = np.random.randn(1024, 1024).astype(np.float32)

    # Warmup
    for _ in range(3):
        sess_dml.run(None, {"A": a, "B": b})

    # Benchmark DirectML
    N = 20
    t0 = time.perf_counter()
    for _ in range(N):
        sess_dml.run(None, {"A": a, "B": b})
    dt_dml = (time.perf_counter() - t0) / N
    gflops_dml = 2 * 1024**3 / dt_dml / 1e9

    print(f"\nDirectML MatMul 1024x1024:")
    print(f"  Time   : {dt_dml*1000:.2f} ms")
    print(f"  GFLOPS : {gflops_dml:.1f}")

    # ── 4. Run on CPU for comparison ────────────────────────────────
    sess_cpu = ort.InferenceSession(
        tmp, providers=["CPUExecutionProvider"]
    )

    for _ in range(3):
        sess_cpu.run(None, {"A": a, "B": b})

    t0 = time.perf_counter()
    for _ in range(N):
        sess_cpu.run(None, {"A": a, "B": b})
    dt_cpu = (time.perf_counter() - t0) / N
    gflops_cpu = 2 * 1024**3 / dt_cpu / 1e9

    print(f"\nCPU MatMul 1024x1024:")
    print(f"  Time   : {dt_cpu*1000:.2f} ms")
    print(f"  GFLOPS : {gflops_cpu:.1f}")

    speedup = dt_cpu / dt_dml if dt_dml > 0 else 0
    print(f"\nSpeedup DirectML vs CPU: {speedup:.1f}x")

    os.remove(tmp)

    # ── 5. Verdict ──────────────────────────────────────────────────
    if "DmlExecutionProvider" in active_dml and speedup > 1.2:
        print(f"\n{'='*60}")
        print("  DirectML utilise bien votre GPU AMD !")
        print(f"  Acceleration: {speedup:.1f}x plus rapide que CPU")
        print(f"{'='*60}")
    elif "DmlExecutionProvider" in active_dml:
        print(f"\n{'='*60}")
        print("  DirectML actif (speedup faible sur ce micro-benchmark)")
        print(f"{'='*60}")
    else:
        print(f"\n{'='*60}")
        print("  WARNING: DirectML NON actif — execution CPU uniquement")
        print(f"{'='*60}")

    _check_pytorch()


def _check_pytorch():
    print()
    try:
        import torch
        print(f"PyTorch       : {torch.__version__}")
        print(f"CUDA          : {torch.cuda.is_available()} (attendu: False)")
        print(f"Device        : CPU (GPU via ONNX Runtime DirectML)")
    except ImportError:
        print("PyTorch       : non installe")


if __name__ == "__main__":
    main()
