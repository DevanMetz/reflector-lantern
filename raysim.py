"""2D (meridional) ray trace of the lantern reflector. Tune params to match lantern.scad."""
import numpy as np, sys

P = dict(r_led=29.6, z_tip=14.0, th_in=35.0, th_out=62.0, R_ref=50.0, R_tube=54.0, led_half=60.0)
for a in sys.argv[1:]:
    k, v = a.split("="); P[k] = float(v)

def zp(r):
    k = (P["th_out"] - P["th_in"]) / P["R_ref"]
    th = np.radians(P["th_in"] + k * r)
    return P["z_tip"] + (np.log(np.cos(np.radians(P["th_in"]))) - np.log(np.cos(th))) / np.radians(k)

def slope(r):
    return np.radians(P["th_in"] + (P["th_out"] - P["th_in"]) / P["R_ref"] * r)

z_rim = zp(P["R_ref"])
res = {"mirror": [], "direct": [], "lost": 0.0}
hts = []
tot = 0.0
for phi in np.linspace(-P["led_half"], P["led_half"], 2401):
    w = np.cos(np.radians(phi)); tot += w
    d = np.array([np.sin(np.radians(phi)), np.cos(np.radians(phi))])
    p = np.array([P["r_led"], 0.0])
    hit = None
    for t in np.arange(0, 400, 0.05):
        q = p + d * t
        if abs(q[0]) >= P["R_tube"] or q[1] > z_rim + 5: break
        if abs(q[0]) <= P["R_ref"] and q[1] >= zp(abs(q[0])):
            hit = q; break
    if hit is None:
        if abs(q[0]) >= P["R_tube"] and q[1] <= z_rim:
            res["direct"].append((90 - abs(phi), w)); hts.append((q[1], w))
        else: res["lost"] += w
        continue
    s = np.sign(hit[0]) or 1
    th = slope(abs(hit[0]))
    n = np.array([s * np.sin(th), -np.cos(th)])   # surface normal facing down/outward
    r = d - 2 * np.dot(d, n) * n
    if r[0] * s <= 0: res["lost"] += w; continue
    tt = (P["R_tube"] - abs(hit[0])) / abs(r[0])
    zt = hit[1] + r[1] * tt
    if zt < 0: res["lost"] += w; continue
    res["mirror"].append((np.degrees(np.arctan2(r[1], abs(r[0]))), w)); hts.append((zt, w))

m = sum(w for _, w in res["mirror"]) / tot
dr = sum(w for _, w in res["direct"]) / tot
print(f"reflector rim height above LEDs: {z_rim:.1f} mm")
print(f"via mirror {m:.0%}  direct to wall {dr:.0%}  lost {res['lost']/tot:.0%}")
if res["mirror"]:
    e = np.array(res["mirror"]); print(f"mirror beam elevation: {e[:,0].min():.0f} to {e[:,0].max():.0f} deg")
h = np.array(hts)
hist, edges = np.histogram(h[:, 0], bins=8, range=(0, z_rim), weights=h[:, 1])
print("light on diffuser wall by height (bottom->top):")
for i in range(len(hist)):
    print(f"  {edges[i]:5.1f}-{edges[i+1]:5.1f} mm  " + "#" * int(60 * hist[i] / hist.max()))
