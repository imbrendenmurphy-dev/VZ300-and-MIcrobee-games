"""First display line after field-sync end, in kernel lines. 62 (picture on line 118 of 312, counting from the
start of field sync): photos of v1.4 on a real VZ300 showed the finale Kefrens holding VRAM row 1, which only
happens if the picture starts 62 lines after FS ends, not 64. RASTEST's D LINE reading of 64 was off by two."""
D = 62
