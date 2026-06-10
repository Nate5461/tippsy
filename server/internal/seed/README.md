# Seed data format

`cmd/seed` imports every `*.json` file in `internal/seed/data/` (alphabetical
order) into the **official** catalogue. Imports are idempotent — ingredients
upsert by case-insensitive name, recipes by `slug` — so re-running after edits
updates rows in place. Drop new files (e.g. content extracted from an epub)
into the data directory and run `make seed`.

```json
{
  "ingredients": [
    { "name": "Vodka", "kind": "spirit", "abv": 40 },
    { "name": "Grey Goose", "kind": "spirit", "abv": 40, "parent": "Vodka" },
    { "name": "Lime Juice", "kind": "juice", "abv": 0, "description": "Freshly squeezed" }
  ],
  "recipes": [
    {
      "slug": "daiquiri",
      "name": "Daiquiri",
      "method": "shaken",
      "glass": "coupe",
      "sweetness": 5,
      "attribution": "Classic",
      "description": "The benchmark rum sour.",
      "instructions": "Shake hard with ice and double-strain into a chilled coupe.",
      "ingredients": [
        { "name": "White Rum", "amount": 60, "unit": "ml" },
        { "name": "Lime Juice", "amount": 25, "unit": "ml" },
        { "name": "Simple Syrup", "amount": 15, "unit": "ml" },
        { "name": "Lime", "amount": 1, "unit": "wedge", "optional": true, "note": "garnish" }
      ]
    }
  ]
}
```

Field notes:

- **kind**: `spirit`, `liqueur`, `fortified_wine`, `wine`, `beer_cider`,
  `bitters`, `juice`, `syrup`, `soda_mixer`, `dairy_egg`, `fruit`,
  `herb_spice`, `garnish`, `other`.
- **parent**: name of the generic this ingredient is a brand/style of
  (`Grey Goose` → `Vodka`). Owning the brand satisfies recipes that call for
  the generic. The parent may live in the same file or already in the catalogue.
- **method**: `shaken`, `stirred`, `built`, `blended`, `other` (default
  `stirred`). Drives the dilution factor in the strength estimate.
- **unit**: a code from the `units` table — volume: `ml`, `cl`, `oz`, `tsp`,
  `tbsp`, `barspoon`, `dash`, `drop`, `splash`, `top`; count: `piece`, `slice`,
  `wedge`, `twist`, `leaf`, `sprig`, `pinch`, `cube`, `rim`. Omit `unit`/`amount`
  for "to taste" lines. Authoring in oz is fine — the API renders both systems
  (1 oz = 30 ml bartending convention).
- **sweetness**: author-set 0 (bone dry) – 10 (dessert). Strength is *not*
  authored — it is computed from ingredient ABVs, volumes, and method.
- **optional** lines (garnishes, rims) are ignored when matching against a
  user's bar for "what can I make".
- A recipe line's `name` must resolve to an ingredient in the same file or one
  already seeded.
