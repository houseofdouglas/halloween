#!/usr/bin/env python3
"""Render cad/anim.scad to ../eyes_preview.mp4 (needs openscad + ffmpeg)."""
import os, subprocess, sys, tempfile
from concurrent.futures import ThreadPoolExecutor

FPS = 24
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "eyes_preview.mp4")

# (scene, seconds, camera(t) -> gimbal "tx,ty,tz,rx,ry,rz,dist")
SCENES = [
    (1, 5.0, lambda t: f"0,40,10,{55 - 8 * t / 5:.2f},0,{15 + 20 * t / 5:.2f},{720 - 140 * t / 5:.1f}"),
    (2, 6.0, lambda t: f"0,40,5,{40:.2f},0,{-15 + 30 * t / 6:.2f},440"),
    (3, 15.0, lambda t: "0,30,0,180,0,180,560"),
]

def frames():
    n = 0
    for seg, dur, cam in SCENES:
        for i in range(int(dur * FPS)):
            t = i / FPS
            yield n, seg, t, cam(t)
            n += 1

def render(tmp, job):
    n, seg, t, cam = job
    subprocess.run(["openscad", "-o", f"{tmp}/f{n:04d}.png", "--imgsize", "1280,720",
                    "--colorscheme", "Starnight", "--camera", cam,
                    "-D", f"seg={seg}", "-D", f"tt={t:.4f}", os.path.join(HERE, "anim.scad")],
                   check=True, capture_output=True)

with tempfile.TemporaryDirectory() as tmp:
    jobs = list(frames())
    with ThreadPoolExecutor(os.cpu_count()) as ex:
        for k, _ in enumerate(ex.map(lambda j: render(tmp, j), jobs)):
            if k % 48 == 0: print(f"{k}/{len(jobs)}", flush=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", f"{tmp}/f%04d.png",
                    "-c:v", "h264_videotoolbox", "-b:v", "6M", "-pix_fmt", "yuv420p", OUT], check=True)
print("wrote", os.path.abspath(OUT))
