# Reviewed Verdi catalog bundle

Author: Codex (AI assistant). Date: 2026-10-31 (Asia/Jakarta).

`reviewed-entries.json` contains 24 independently authored summaries and factual
identifiers for the accepted Popular policy. It contains no copied source images
or article bodies. Each entry carries its primary-source URL, capture digest,
content review and text-rights scope. Original captures remain ignored in
`claude-import/catalog-review-2026-10-31/`; they are not distributed in the app.

The separate AI reviewer checked all 22 NC State captures and both RHS profiles,
including the four qualified fertilizer intervals. The initial RHS excerpts were
insufficient: the retained evidence was extended with explicitly labeled AI
observations, and the reviewer independently opened both primary pages before
closing the finding. Unknown animal-specific evidence and difficulty stay Unknown.
No fixed watering intervals were invented. These checks do not certify diagnosis
or pet safety and do not establish a full launch inventory.

`generic-asset.json` identifies the existing unmodified Figma 11:407 illustration,
its bytes/dimensions and user-confirmed commercial rights (SRC-011). The retained
`artwork-evidence.txt` is the exact hashed evidence statement, not a new permission.
`species-assets.json` adds seven explicitly identified botanical exports from the
same Figma file, with byte hashes, dimensions and the retained
`species-art-evidence.txt` identity/rights evidence. Package version
`verdi-2026-11-01.1` preserves all 24 entry bytes and Popular order. The interface
resolves mappings only from validated catalog state; unknown/custom plants keep
the generic fallback. User cover photos take precedence.

Run `python3 tooling/catalog/build_catalog.py` from the app root. It deterministically
writes the two bundled JSON files. The native `CatalogPackage` validator checks
actual content/review/source/rights structure, hashes, Popular membership, bounds
and decoded PNG bytes before any install. `CatalogTests` validates the actual
bundle and rejects altered/pending records; generated fixtures contain identical
bundle bytes. Rebuild those fixtures after a reviewed package change:

```sh
cp apps/mobile/assets/catalog/*.json apps/mobile/packages/verdi_native/Tests/VerdiNativeTests/Fixtures/catalog/
cp apps/mobile/assets/illustrations/empty-plants.png apps/mobile/packages/verdi_native/Tests/VerdiNativeTests/Fixtures/catalog/generic.png
cp apps/mobile/assets/catalog_art/*.png apps/mobile/packages/verdi_native/Tests/VerdiNativeTests/Fixtures/catalog/
swift test --package-path apps/mobile/packages/verdi_native --filter CatalogTests
```

Changing content requires a new reviewed entry version and package version;
regeneration does not approve new facts or rights. Review fields are evidence
records, not booleans to toggle to make a failing validator pass. Additions beyond
the fixed Popular inventory do not change its membership/order. No upstream
article/photo rights are inferred from the user's rights to imported artwork.

Unicode search uses separately pinned official Unicode 15.1 inputs/digests in
`tooling/unicode/generate.py` and the included Unicode license. Generated code
uses full default C/F folding and White_Space, without accent normalization or
locale-dependent lowercasing.
