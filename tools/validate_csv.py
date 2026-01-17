#!/usr/bin/env python3
import csv
import sys
from pathlib import Path

REQUIRED_COLUMNS = {
    "id",
    "level",
    "category",
    "subcategory",
    "stem",
    "choicea",
    "choiceb",
    "choicec",
    "choiced",
    "answerindex",
    "explanation",
    "difficulty",
    "image",
}

CATEGORY_ALIASES = {
    "ethics",
    "ethique",
    "quantitative methods",
    "quant",
    "quantitative",
    "qm",
    "economics",
    "economie",
    "financial reporting & analysis",
    "financial reporting and analysis",
    "fra",
    "corporate finance",
    "corp fin",
    "equity investments",
    "equity",
    "fixed income",
    "fi",
    "derivatives",
    "derives",
    "alternative investments",
    "alts",
    "portfolio management & wealth planning",
    "portfolio management",
    "portfolio",
}


def read_text_utf8(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        print("ERROR: fichier non UTF-8.")
        sys.exit(2)


def normalize(s: str) -> str:
    return s.strip().lower()


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: tools/validate_csv.py <file.csv>")
        return 2

    path = Path(sys.argv[1])
    if not path.exists():
        print(f"ERROR: fichier introuvable: {path}")
        return 2

    text = read_text_utf8(path)
    if not text.strip():
        print("ERROR: fichier vide.")
        return 2

    errors = []
    warnings = []

    reader = csv.reader(text.splitlines(), strict=True)
    try:
        header = next(reader)
    except StopIteration:
        print("ERROR: pas d'en-tete.")
        return 2

    header_map = {normalize(h): i for i, h in enumerate(header)}
    missing = sorted([c for c in REQUIRED_COLUMNS if c not in header_map])
    if missing:
        errors.append(f"Colonnes manquantes: {', '.join(missing)}")

    seen_ids = set()
    row_num = 1

    for row in reader:
        row_num += 1
        if not row or all(not cell.strip() for cell in row):
            continue

        def field(name: str) -> str:
            idx = header_map.get(name)
            if idx is None or idx >= len(row):
                return ""
            return row[idx]

        qid = field("id").strip()
        if not qid:
            errors.append(f"Ligne {row_num}: id vide")
        elif qid in seen_ids:
            warnings.append(f"Ligne {row_num}: id duplique ({qid})")
        else:
            seen_ids.add(qid)

        level_raw = field("level").strip()
        if level_raw not in {"1", "2", "3"}:
            errors.append(f"Ligne {row_num}: level invalide ({level_raw})")

        category = normalize(field("category"))
        if not category:
            errors.append(f"Ligne {row_num}: category vide")
        elif category not in CATEGORY_ALIASES:
            warnings.append(f"Ligne {row_num}: category inconnue ({category})")

        stem = field("stem").strip()
        if not stem:
            errors.append(f"Ligne {row_num}: stem vide")

        choices = [field("choicea"), field("choiceb"), field("choicec"), field("choiced")]
        non_empty_choices = [c for c in choices if c.strip()]
        if len(non_empty_choices) < 2:
            errors.append(f"Ligne {row_num}: moins de 2 choix")

        answer_raw = field("answerindex").strip()
        if answer_raw == "":
            errors.append(f"Ligne {row_num}: answerIndex vide")
        else:
            try:
                answer_idx = int(answer_raw)
            except ValueError:
                errors.append(f"Ligne {row_num}: answerIndex non entier ({answer_raw})")
            else:
                if answer_idx < 0 or answer_idx >= len(non_empty_choices):
                    errors.append(
                        f"Ligne {row_num}: answerIndex hors limites ({answer_idx})"
                    )

        difficulty_raw = field("difficulty").strip()
        if difficulty_raw:
            try:
                int(difficulty_raw)
            except ValueError:
                errors.append(f"Ligne {row_num}: difficulty non entier ({difficulty_raw})")

    if errors:
        print("Erreurs:")
        for e in errors:
            print(f"- {e}")

    if warnings:
        print("Avertissements:")
        for w in warnings:
            print(f"- {w}")

    if errors:
        print(f"\nResultat: ECHEC ({len(errors)} erreurs, {len(warnings)} avertissements)")
        return 1

    print(f"Resultat: OK ({len(warnings)} avertissements)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
