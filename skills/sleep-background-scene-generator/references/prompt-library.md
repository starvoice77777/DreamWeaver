# Sleep Scene Prompt Library

Use these mappings to make a scene recognizable without adding people.

## Symbolic object mappings

| Scene cue | Objects and environmental signals |
| --- | --- |
| Rainy eaves | wet roof edge, paper lantern, rain beads, dark courtyard |
| Forest stream | mossy rocks, shallow clear stream, ferns, misted ravine |
| Snow study | wooden desk, open book, warm lamp, mug, snowy window |
| Cloud breathing | layered clouds, distant sunrise glow, soft atmospheric depth |
| Hair-washing companionship | empty ceramic shampoo basin, shower stream, airy foam, folded towel, unbranded amber bottles, warm lamp |
| Fireside whisper | low fireplace, stacked logs, wool throw, ceramic cup, dark room |
| Moon lake | still lake, moon reflection, reeds, distant mountains |
| Emotional fluid | abstract flowing color ribbons, deep navy field, restrained amber/lilac/teal glow |

## Hard constraints for object-only scenes

Put the following near the start and end of the prompt:

```text
Objects only. No people, no face, no head, no hair, no hands, no fingers, no skin, no body, no human silhouette, no human reflection.
```

Then name the exact symbolic objects. Avoid vague prompts such as “a relaxing scene” because they often produce incidental people or generic stock imagery.

## Mobile composition defaults

- Portrait ratio: 9:19.5 or the project’s target ratio.
- Focal area: upper-middle or middle; keep the bottom 25–33% quiet and darker.
- Card crop: keep one strong object readable near the center, with enough edge context for a rounded card crop.
- Text/UI safety: no baked-in copy, signage, labels, logos, or watermarks.
- Lighting: low-contrast ambient light; use one warm practical source plus cool ambient fill when a night mood is requested.

## Edit invariants

When editing an existing generated scene, list exactly what changes and what remains:

```text
Change only: <objects or subject removal>
Preserve: composition, palette, lighting, camera perspective, wallpaper ratio, and quiet UI area
```

Do not request a full restyle when the user only wants a person removed; targeted edits preserve visual continuity better.
