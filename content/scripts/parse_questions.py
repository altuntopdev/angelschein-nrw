import fitz
import json
import re
import sys

CATEGORY_MARKERS = [
    ("ALLGEMEINE FISCHKUNDE", "allgemeine_fischkunde"),
    ("SPEZIELLE FISCHKUNDE", "spezielle_fischkunde"),
    ("GEWÄSSERKUNDE UND", "gewaesserkunde_und_fischhege"),
    ("NATUR- UND TIERSCHUTZ", "natur_und_tierschutz"),
    ("GERÄTEKUNDE", "geraetekunde"),
    ("GESETZESKUNDE", "gesetzeskunde"),
]

GREEN = 36608  # RGB(0,143,0) -> marks the correct answer option

TR_WORDS = {"ne", "nedir", "nelerdir", "hangi", "hangisi", "hangileri", "nerede", "nerelerde",
            "nereye", "midir", "mıdır", "mudur", "müdür", "mı", "mi", "mu", "mü",
            "kaç", "niçin", "neden", "nasıl", "kim", "kimdir", "yapılır", "olur", "midir?"}
GERMAN_WORDS = {"was", "welche", "welcher", "welches", "welchem", "welchen", "wo", "wie", "wieviel",
                 "wieviele", "wann", "warum", "wodurch", "wozu", "wofür", "womit", "ist", "sind",
                 "darf", "dürfen", "kann", "können", "gilt", "gelten", "muss", "müssen"}

def detect_lang(qtext):
    if re.search(r"[ışğçİĞŞÇ]", qtext):
        return "tr"
    words = re.findall(r"[a-zA-ZäöüÄÖÜß]+", qtext.lower())
    wset = set(words)
    if wset & TR_WORDS:
        return "tr"
    if wset & GERMAN_WORDS:
        return "de"
    return "de"

def flatten_spans(doc):
    """Yield (page_no, block_idx, line_idx, span_idx, text, font, size, color, flags, bold, bbox)"""
    out = []
    for pno, page in enumerate(doc):
        d = page.get_text("dict")
        for bidx, block in enumerate(d.get("blocks", [])):
            for lidx, line in enumerate(block.get("lines", [])):
                for sidx, span in enumerate(line["spans"]):
                    t = span["text"]
                    if t.strip() == "":
                        continue
                    out.append({
                        "page": pno + 1,
                        "block": bidx,
                        "line": lidx,
                        "text": t,
                        "font": span["font"],
                        "size": span["size"],
                        "color": span["color"],
                        "flags": span["flags"],
                        "bold": bool(span["flags"] & 16) or "Bold" in span["font"],
                    })
    return out

def main(pdf_path, out_path):
    doc = fitz.open(pdf_path)
    spans = flatten_spans(doc)

    # merge spans into lines (page, block, line) -> concatenated text + info
    lines = {}
    order = []
    for s in spans:
        key = (s["page"], s["block"], s["line"])
        if key not in lines:
            lines[key] = {"page": s["page"], "spans": [], "text": ""}
            order.append(key)
        lines[key]["spans"].append(s)
        lines[key]["text"] += s["text"]

    line_list = [lines[k] for k in order]

    q_start_re = re.compile(r"^\s*(\d+)\.\s*(.*)")

    current_category = None
    questions = []  # list of dicts, two entries per number (de, tr) merged later
    pending = {}  # number -> {"de": {...}, "tr": {...}}
    stray_option_buffer = []

    i = 0
    n = len(line_list)
    unresolved = []

    while i < n:
        ln = line_list[i]
        text = ln["text"].strip()

        matched_cat = None
        for marker, slug in CATEGORY_MARKERS:
            if text.upper().startswith(marker):
                matched_cat = slug
                break
        if matched_cat:
            current_category = matched_cat
            i += 1
            continue

        m = q_start_re.match(text)
        # NB: the source PDF is inconsistent about bolding the Turkish header line
        # (bold on some pages, plain on others), so question-start detection relies
        # only on the "<number>. " prefix, not on font weight.
        if m and current_category:
            qnum = int(m.group(1))
            qtext = m.group(2).strip()
            # language is decided from the header line alone, before any note/option text can pollute it
            lang = detect_lang(qtext)
            # collect option lines until next bold-numbered line or category header
            options = []
            note_parts = []
            j = i + 1
            while j < n:
                ln2 = line_list[j]
                t2 = ln2["text"].strip()
                if not t2:
                    j += 1
                    continue
                if q_start_re.match(t2):
                    break
                is_cat = any(t2.upper().startswith(mk) for mk, _ in CATEGORY_MARKERS)
                if is_cat:
                    break

                note_m = re.match(r"^(A[cç]\S*klama)\s*:?\s*(.*)", t2, re.IGNORECASE)
                if note_m or note_parts:
                    note_parts.append(note_m.group(2) if note_m else t2)
                    j += 1
                    continue

                om = re.match(r"^\s*([abc])\)\s*(.*)", t2)
                if om:
                    letter = om.group(1)
                    otext = om.group(2).strip()
                    is_green = any(sp["color"] == GREEN for sp in ln2["spans"])
                    options.append({"letter": letter, "text": otext, "correct": is_green})
                elif options:
                    # continuation of previous option's text (wrapped line)
                    options[-1]["text"] += " " + t2
                    if any(sp["color"] == GREEN for sp in ln2["spans"]):
                        options[-1]["correct"] = True
                else:
                    # continuation of question text itself
                    qtext += " " + t2
                j += 1

            note = " ".join(note_parts).strip() or None
            entry = {"category": current_category, "number": qnum, "question": qtext, "options": options, "note": note, "page": ln["page"]}

            slot = pending.setdefault((current_category, qnum), {})
            if lang not in slot:
                slot[lang] = entry
            else:
                # already has this lang -> conflict, store as unresolved extra
                unresolved.append(entry)

            i = j
            continue

        i += 1

    for (cat, num), slot in pending.items():
        de = slot.get("de")
        tr = slot.get("tr")

        # if one language is missing its green (correct) mark but the other
        # language has exactly one, borrow the letter (options are in the same a/b/c order in both languages)
        def greens(e):
            return [o["letter"] for o in e["options"]] and [o["letter"] for o in e["options"] if o["correct"]]

        if de and tr and len(de["options"]) == len(tr["options"]) == 3:
            gd, gt = greens(de), greens(tr)
            if len(gd) != 1 and len(gt) == 1:
                for o in de["options"]:
                    o["correct"] = (o["letter"] == gt[0])
                de["correct_source"] = "borrowed_from_tr"
            elif len(gt) != 1 and len(gd) == 1:
                for o in tr["options"]:
                    o["correct"] = (o["letter"] == gd[0])
                tr["correct_source"] = "borrowed_from_de"

        questions.append({
            "category": cat,
            "number": num,
            "de": de,
            "tr": tr,
        })

    questions.sort(key=lambda q: (q["category"], q["number"]))

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({"questions": questions, "unresolved_extra": unresolved}, f, ensure_ascii=False, indent=2)

    # --- report ---
    by_cat = {}
    problems = []
    for q in questions:
        by_cat.setdefault(q["category"], 0)
        by_cat[q["category"]] += 1
        for langkey in ("de", "tr"):
            e = q[langkey]
            if not e:
                problems.append(f"{q['category']} #{q['number']}: missing {langkey} block")
                continue
            greens = sum(1 for o in e["options"] if o["correct"])
            if greens != 1:
                problems.append(f"{q['category']} #{q['number']} ({langkey}, p.{e['page']}): {greens} green options (expected 1)")
            if len(e["options"]) != 3:
                problems.append(f"{q['category']} #{q['number']} ({langkey}, p.{e['page']}): {len(e['options'])} options (expected 3)")

    print("=== per-category counts ===")
    for c, n_ in by_cat.items():
        print(f"{c}: {n_}")
    print(f"\nTOTAL questions: {len(questions)}")
    print(f"unresolved extra blocks (lang collision): {len(unresolved)}")
    print(f"\n=== problems ({len(problems)}) ===")
    for p in problems[:60]:
        print(p)
    if len(problems) > 60:
        print(f"... and {len(problems) - 60} more")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
