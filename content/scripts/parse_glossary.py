import fitz
import json
import sys

def col_for_x(x):
    if x < 150:
        return "de"
    if x < 410:
        return "tr"
    return "lat"

def main(pdf_path, out_path):
    doc = fitz.open(pdf_path)
    rows = []  # {"de": [...lines], "tr": [...], "lat": [...]}
    for pno, page in enumerate(doc):
        d = page.get_text("dict")
        col_lines = {"de": [], "tr": [], "lat": []}
        for block in d.get("blocks", []):
            for line in block.get("lines", []):
                text = "".join(sp["text"] for sp in line["spans"]).strip()
                if not text:
                    continue
                x0 = min(sp["bbox"][0] for sp in line["spans"])
                y0 = line["bbox"][1]
                col = col_for_x(x0)
                col_lines[col].append((y0, text))

        # skip header lines (ALMANCA / TÜRKÇE / LİTERATÜR labels, title)
        for col in col_lines:
            col_lines[col] = [(y, t) for y, t in col_lines[col]
                               if t.upper() not in ("ALMANCA", "TÜRKÇE", "LİTERATÜR")
                               and "SÖZLÜĞÜ" not in t.upper()]

        # cluster each column's lines into row-groups by y proximity (tolerance ~14pt = one text line)
        def cluster(lines):
            lines = sorted(lines)
            groups = []
            for y, t in lines:
                if groups and y - groups[-1][-1][0] < 14:
                    groups[-1].append((y, t))
                else:
                    groups.append([(y, t)])
            return [(g[0][0], " ".join(t for _, t in g)) for g in groups]

        de_groups = cluster(col_lines["de"])
        tr_groups = cluster(col_lines["tr"])
        lat_groups = cluster(col_lines["lat"])

        # merge the three column groups into rows by nearest y (primary axis = DE column, since every row has a DE term)
        used_tr = [False] * len(tr_groups)
        used_lat = [False] * len(lat_groups)

        def find_match(y, groups, used):
            best = None
            best_dist = 10  # points tolerance
            for idx, (gy, gt) in enumerate(groups):
                if used[idx]:
                    continue
                dist = abs(gy - y)
                if dist < best_dist:
                    best = idx
                    best_dist = dist
            return best

        for y, de_text in de_groups:
            ti = find_match(y, tr_groups, used_tr)
            li = find_match(y, lat_groups, used_lat)
            tr_text = None
            lat_text = None
            if ti is not None:
                used_tr[ti] = True
                tr_text = tr_groups[ti][1]
            if li is not None:
                used_lat[li] = True
                lat_text = lat_groups[li][1]
            rows.append({"de": de_text, "tr": tr_text, "lat": lat_text, "page": pno + 1})

        # leftover TR/LAT groups with no DE match (rare, but keep for review)
        for idx, (y, t) in enumerate(tr_groups):
            if not used_tr[idx]:
                rows.append({"de": None, "tr": t, "lat": None, "page": pno + 1, "orphan": True})
        for idx, (y, t) in enumerate(lat_groups):
            if not used_lat[idx]:
                rows.append({"de": None, "tr": None, "lat": t, "page": pno + 1, "orphan": True})

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, indent=2)

    print(f"TOTAL rows: {len(rows)}")
    orphans = [r for r in rows if r.get("orphan")]
    missing_tr = [r for r in rows if not r.get("orphan") and not r.get("tr")]
    print(f"orphan (unmatched) rows: {len(orphans)}")
    print(f"rows missing TR translation: {len(missing_tr)}")
    print("\n--- sample ---")
    for r in rows[:15]:
        print(r)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
