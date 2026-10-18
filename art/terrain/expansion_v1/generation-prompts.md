# Generation prompts

Mode: built-in imagegen. Reference inputs: existing project art (style/camera only). Original outputs retained under Codex generated_images.

## foliage-v1.png

```text
Use case: stylized-concept. Asset type: production-ready isometric scenery sprite atlas for an East Asian historical fantasy Godot RPG.
Primary request: ONE PNG atlas containing six different wilderness vegetation props, on REAL transparent alpha background.
Reference image role: the provided existing props atlas is STYLE AND CAMERA REFERENCE ONLY, do not reproduce its objects or its colored background.
Style: richly detailed painterly pre-rendered late-1990s/early-2000s East Asian isometric RPG art; believable weathered natural surfaces, muted olive green and earth tones, crisp readable silhouette. Consistent elevated orthographic 2:1 isometric view, soft neutral upper-left light.
Layout: landscape 1536 by 1024 pixels, STRICT 3 columns by 2 rows, six equal 512 by 512 cells. Each complete object fully contained in its cell, centered horizontally, ground contact baseline near cell y=460. Leave at least 35 pixels transparent clearance on ALL four cell edges. Do not spill or overlap neighboring cells. Objects isolated, no landscape backdrops, no ground tiles, no text or grids.
Cell order left-to-right then top-to-bottom:
1 clustered green bamboo with visible jointed stalks and leafy canopy;
2 full autumn maple tree with rust-red and amber canopy and exposed roots;
3 old leafless gnarled tree, expressive complete branching silhouette;
4 dense tea-green flowering shrub with small pale flowers;
5 reed and cattail clump with a few smooth stones at root base;
6 mossy fallen hollow log with tiny mushrooms on the bark.
Each cell contains ONLY its named distinct prop. No pine trees, buildings, people, labels, watermark, checkerboard, colored backdrop. Background must be true transparency; compact contact shadows only.
```

## village-v1.png

```text
Use case: stylized-concept. Asset type: transparent isometric village-utility scenery sprite atlas for Godot.
Produce ONE landscape PNG atlas 1536x1024 with a STRICT 3-column by 2-row grid of six COMPLETE separate props. Reference is STYLE/CAMERA only, do not include existing reference subjects. Richly detailed painterly pre-rendered classic East Asian historical RPG style, muted earth palette, mossy gray stone, aged brown timber, soft upper-left light, elevated orthographic 2:1 isometric view consistent for every object.
Background MUST be actual transparent alpha, no colored background, no floor planes or landscape. Each prop fits independently into its own 512x512 cell, centered horizontally, contact baseline around y=460 within the cell, at least 35px empty transparent clearance from every edge. No cropping, overlap, labels or grid lines.
Top row left to right: (1) small circular stone village well with two timber uprights, a crossbeam, rope and hanging wooden bucket, no tiled roof; (2) simple rustic market stall with faded ochre canvas canopy over four wooden posts, baskets of vegetables and earthen jars under it; (3) weathered two-wheel wooden handcart with a pair of closed burlap grain sacks, drawbar completely visible.
Bottom row left to right: (4) compact traditional outdoor clay-and-brick cooking oven with side pile of firewood, no smoke; (5) complete short bamboo fence segment with posts and crossrails, diagonal isometric orientation; (6) cluster of two aged storage barrels, one earthenware jar and a coiled rope.
No people, animals, text, symbols, watermark, modern plastic, giant buildings or decorative scenic backgrounds. Preserve readable clean full silhouettes and TRUE transparency.
```

## ruins-v1.png

```text
Use case: stylized-concept. Asset type: transparent isometric ancient-ruins scenery sprite atlas for a classic East Asian fantasy Godot RPG.
ONE landscape PNG sprite atlas 1536x1024, strict 3 columns by 2 rows, six separate COMPLETE props. Reference is art-style and elevated 2:1 orthographic isometric camera only, not objects nor colored background. Detailed painterly pre-rendered period RPG style, restrained warm gray and moss olive palette, naturally eroded stone, aged timber, muted patinated bronze. Consistent soft upper-left light and game-readable silhouettes.
REAL transparent alpha background, no opaque backdrop. Each complete prop contained in its own 512x512 cell with >=35px empty transparent margin on every side, centered, ground contact baseline near local y=460. No cropping, overlapping cells, labels, borders or scenery connecting objects.
Top row left to right: 1 a small broken ancient stone archway with jagged missing upper stones and moss-covered base, no human figures; 2 an old carved stone guardian lion on a modest square plinth, lion visible in three-quarter view; 3 a squat bronze hanging bell suspended from an aged freestanding timber frame with a very small tiled roof.
Bottom row left to right: 4 a collapsed carved stone column lying diagonally with a few broken fragments, entire length visible; 5 a weathered stone ritual altar with stepped square base, incised simple geometric decoration and unlit bowl, no supernatural glow; 6 a cluster of pale quartz crystal spikes growing from dark natural rock, subtle cool translucency, no particles.
No text, readable inscriptions, people, animals other than the stone statue, modern objects, glowing backdrop, floor planes, checkerboard, watermarks. Every sprite isolated on TRUE alpha transparency.
```

## surfaces-v1.png

```text
Use case: stylized-concept. Asset type: ground-material texture source atlas for a classic East Asian painterly isometric Godot RPG.
ONE exactly square 1024 by 1024 PNG with an exact 2x2 quadrant layout, four 512x512 flat top-down material samples, all sample edges meet exactly at canvas x=512 and y=512 with NO gutters, text, borders or perspective.
Reference image is ground-detail level and painterly material language only. New samples must be visually distinct from the reference mossy courtyard and water.
Top LEFT: warm beige dry sand with tiny natural grains and sparse subtle small pebbles, evenly distributed soft ripples, no footprints.
Top RIGHT: dry ochre clay soil with natural irregular polygonal desiccation cracks, earthy fine texture, no plants.
Bottom LEFT: cool off-white packed snow with subtle bluish shallow granular relief and occasional ice flecks, no tracks, no opaque rocks.
Bottom RIGHT: dark slate-gray rough gravel ground, evenly mixed small angular stones and dusty grit, no grass.
Each sample is a full-bleed surface with uniform scale and diffuse ambient illumination, no cast directional shadows or central focal object. Aim for repeat-friendly edges within each sample and game-readable detail when reduced to tiny floor tiles. Flat overhead view; no isometric diamonds (projection is handled by the game); no 3D piles, no large rocks, no icons, no objects, no text, no watermark. Muted painterly realism compatible with the supplied RPG material atlas. Opaque background.
```
