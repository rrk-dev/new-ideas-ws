"""ctypes binding of the app's STT C ABI (native/bridge/vv_whisper.h, ABI 1).

The harness transcribes through the **same bridge and default parameters the
app uses** (vv_stt_default_params: greedy, temperature fallback, no_context,
suppress_nst, thresholds), on the host build `native/build.sh host`.
"""
from __future__ import annotations

import ctypes as C
import threading
from pathlib import Path


class InitParams(C.Structure):
    _fields_ = [("struct_size", C.c_uint32), ("use_gpu", C.c_int32),
                ("flash_attn", C.c_int32), ("gpu_device", C.c_int32)]


class Params(C.Structure):
    _fields_ = [
        ("struct_size", C.c_uint32), ("language", C.c_char_p), ("translate", C.c_int32),
        ("n_threads", C.c_int32), ("beam_size", C.c_int32), ("temperature", C.c_float),
        ("temperature_inc", C.c_float), ("initial_prompt", C.c_char_p),
        ("carry_initial_prompt", C.c_int32), ("no_context", C.c_int32),
        ("token_timestamps", C.c_int32), ("suppress_nst", C.c_int32),
        ("entropy_thold", C.c_float), ("logprob_thold", C.c_float),
        ("no_speech_thold", C.c_float),
    ]


class Token(C.Structure):
    _fields_ = [("text", C.c_char_p), ("p", C.c_float), ("t0_ms", C.c_int64), ("t1_ms", C.c_int64)]


class Segment(C.Structure):
    _fields_ = [
        ("index", C.c_int32), ("t0_ms", C.c_int64), ("t1_ms", C.c_int64),
        ("t0_range", C.c_int32), ("t0_src_ms", C.c_int64), ("t1_range", C.c_int32),
        ("t1_src_ms", C.c_int64), ("avg_logprob", C.c_float), ("no_speech_prob", C.c_float),
        ("text", C.c_char_p), ("n_tokens", C.c_int32), ("tokens", C.POINTER(Token)),
    ]


class Range(C.Structure):
    _fields_ = [("path", C.c_char_p), ("start_ms", C.c_int64), ("end_ms", C.c_int64)]


ProgressCb = C.CFUNCTYPE(None, C.c_void_p, C.c_int32)
SegmentCb = C.CFUNCTYPE(None, C.c_void_p, C.POINTER(Segment))
DoneCb = C.CFUNCTYPE(None, C.c_void_p, C.c_int32, C.c_int64, C.c_int64, C.c_int32)


class Callbacks(C.Structure):
    _fields_ = [("on_progress", ProgressCb), ("on_segment", SegmentCb), ("on_done", DoneCb)]


class Bridge:
    def __init__(self, lib: Path):
        self.lib = C.CDLL(str(lib))
        L = self.lib
        L.vv_abi_version.restype = C.c_int32
        L.vv_whisper_version.restype = C.c_char_p
        L.vv_stt_default_init_params.restype = InitParams
        L.vv_stt_default_params.restype = Params
        L.vv_stt_create.argtypes = [C.c_char_p, C.POINTER(InitParams), C.POINTER(C.c_void_p)]
        L.vv_stt_create.restype = C.c_int32
        L.vv_stt_transcribe_async.argtypes = [C.c_void_p, C.c_char_p, C.POINTER(Params),
                                              Callbacks, C.c_void_p]
        L.vv_stt_transcribe_async.restype = C.c_int32
        L.vv_stt_transcribe_ranges.argtypes = [C.c_void_p, C.POINTER(Range), C.c_size_t,
                                               C.POINTER(Params), Callbacks, C.c_void_p]
        L.vv_stt_transcribe_ranges.restype = C.c_int32
        L.vv_stt_destroy.argtypes = [C.c_void_p]
        L.vv_stt_free_segment.argtypes = [C.POINTER(Segment)]
        L.vv_stt_last_error.argtypes = [C.c_void_p]
        L.vv_stt_last_error.restype = C.c_char_p
        if L.vv_abi_version() != 1:
            raise RuntimeError(f"bridge ABI {L.vv_abi_version()} != 1")

    @property
    def whisper_version(self) -> str:
        return self.lib.vv_whisper_version().decode()

    def open(self, model: Path, use_gpu: bool) -> "Model":
        ip = self.lib.vv_stt_default_init_params()
        ip.use_gpu = 1 if use_gpu else 0
        h = C.c_void_p()
        rc = self.lib.vv_stt_create(str(model).encode(), C.byref(ip), C.byref(h))
        if rc != 0:
            raise RuntimeError(f"vv_stt_create {rc}: {self.lib.vv_stt_last_error(None)}")
        return Model(self, h)


class Model:
    def __init__(self, bridge: Bridge, handle: C.c_void_p):
        self.b, self.h = bridge, handle

    def close(self) -> None:
        if self.h:
            self.b.lib.vv_stt_destroy(self.h)
            self.h = None

    def transcribe(self, wav: Path, ranges: list[tuple[int, int]] | None = None,
                   language: str = "en", threads: int = 0) -> dict:
        """Returns {text, audio_ms, process_ms, segments}."""
        texts: list[str] = []
        done = threading.Event()
        result: dict = {}

        def on_seg(_u, seg):
            texts.append(seg.contents.text.decode("utf-8", "replace"))
            self.b.lib.vv_stt_free_segment(seg)

        def on_done(_u, status, audio_ms, process_ms, n):
            result.update(status=status, audio_ms=audio_ms, process_ms=process_ms, n=n)
            done.set()

        cbs = Callbacks(ProgressCb(0), SegmentCb(on_seg), DoneCb(on_done))
        p = self.b.lib.vv_stt_default_params()
        p.language = language.encode()
        if threads > 0:
            p.n_threads = threads
        if ranges:
            arr = (Range * len(ranges))(*[Range(str(wav).encode(), s, e) for s, e in ranges])
            rc = self.b.lib.vv_stt_transcribe_ranges(self.h, arr, len(ranges), C.byref(p), cbs, None)
        else:
            rc = self.b.lib.vv_stt_transcribe_async(self.h, str(wav).encode(), C.byref(p), cbs, None)
        if rc != 0:
            raise RuntimeError(f"transcribe {rc}: {self.b.lib.vv_stt_last_error(self.h)}")
        done.wait()
        # Segment callbacks all precede on_done (same worker thread).
        if result["status"] != 0:
            raise RuntimeError(f"transcribe status {result['status']}")
        return {"text": " ".join(t.strip() for t in texts), "audio_ms": result["audio_ms"],
                "process_ms": result["process_ms"], "segments": result["n"]}
