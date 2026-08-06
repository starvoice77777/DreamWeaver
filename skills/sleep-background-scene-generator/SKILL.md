---
name: sleep-background-scene-generator
description: Generate or edit calm, cinematic sleep-aid background scenes for mobile apps, scene cards, and immersive playback views. Use when Codex needs a new raster sleep/relaxation scene, a variant with no people and only symbolic objects, a mobile-ready cover image, or a project integration that maps generated art to an existing scene while preserving an existing animated backdrop.
---

# Sleep Background Scene Generator

Create atmospheric, non-distracting raster backgrounds for sleep and relaxation experiences. Use the built-in `image_gen` tool by default; use the project integration workflow only when the user asks to add the image to an app or repository.

## Workflow

1. **Classify the request.** Decide whether it is a new image, an edit of a supplied/generated image, or an app integration. Treat an attached image as a reference unless the user says to edit it. If the request is ambiguous, generate the image first and do not alter app code.
2. **Choose the visual mode.** Ask whether people are allowed only when it materially affects the scene. For “objects only”, explicitly exclude heads, faces, hair, hands, skin, bodies, silhouettes, and human reflections; tell the model which symbolic objects carry the scene identity.
3. **Compose for mobile.** Default to a portrait wallpaper around 9:19.5. Put the subject in the upper or middle area, keep the lowest third quiet and darker for playback controls, and make the center crop legible as a small card. For a supplied landscape reference, preserve its mood but adapt the composition to portrait unless the user requests otherwise.
4. **Generate or edit.** Read the image-generation skill instructions first when using `image_gen`. For a local edit target, inspect it with `view_image` before calling `image_gen`. Use a single targeted edit for each iteration and preserve requested invariants.
5. **Inspect and validate.** Check that the scene communicates the requested sleep cue, contains no unwanted people or text, has plausible lighting/materials, and leaves usable UI negative space. If the output fails a hard constraint, iterate with that constraint stated first.
6. **Save non-destructively.** For a project-bound image, copy the final output into the project and keep earlier versions with a `-v2`, `-v3` suffix. Report the absolute saved path. Do not overwrite an existing asset unless the user explicitly requests replacement.
7. **Integrate only on request.** When adding to a SwiftUI scene catalog, register the asset in the shared cover loader and use the scene’s existing backdrop route. If the scene already has an animated backdrop, change only the cover/card mapping; do not replace the animated playback view with a static image unless explicitly requested.

## Prompt construction

Use this compact schema when shaping the image prompt:

```text
Use case: photorealistic-natural or stylized-concept
Asset type: mobile sleep-scene wallpaper and/or scene-card cover
Primary request: <scene identity and requested change>
Input images: <reference or edit target, if any>
Scene/backdrop: <place, time, weather>
Subject: <main object or symbolic object set>
Style/medium: cinematic photorealistic, painterly, or specified style
Composition/framing: portrait mobile, focal area, quiet UI area, crop behavior
Lighting/mood: soft, low contrast, safe, sleepy, no harsh highlights
Color palette: <3–5 colors>
Materials/textures: <surfaces that make the cue readable>
Text (verbatim): "" (unless text is explicitly requested)
Constraints: <must preserve / must exclude>
Avoid: logos, watermark, readable text, horror, clutter, uncanny anatomy
```

For reusable prompt patterns and symbolic-object mappings, read [references/prompt-library.md](references/prompt-library.md).

## Project integration notes

For SwiftUI projects with a shared cover loader:

- Add a unique image filename and asset-catalog image set; avoid generic names such as `bg.jpg` that can collide when bundle resources flatten paths.
- Map the scene style to the cover asset so cards and picker rows use the same image.
- Add a custom static backdrop route only for scenes that should become static. For animated scenes, leave `SceneBackdropHost`/equivalent playback routing untouched.
- Use fallback colors that match the generated image so loading failure still feels intentional.
- Run the project’s formatter/lint/build check when available; if Xcode cannot build because simulator runtimes are unavailable, report that environment limitation separately from code/resource validation.

## Output handoff

Return the generated image inline when possible, plus its absolute project path if saved. State whether the image is a new generation or an edit, whether it is portrait-ready, and whether app integration was performed. Keep the final response concise.
