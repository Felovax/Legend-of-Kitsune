# AI art prompt pack: Legend of Kitsune

Goal: a bright, colourful, cute **chibi cartoon** look for a mobile RPG. Soft shading, clean thick outlines, glossy highlights, saturated but friendly colours. Every asset must look like it came from the same artist.

## Ground rules
- **Do not put other games' titles or living artists' names in prompts.** Describe the style instead. It avoids derivative results and legal risk.
- Use **one tool** for the whole game so the style stays consistent. Good options: a tool that can train a custom style model on your own approved images (e.g. Scenario), or one with character/style reference images (e.g. Midjourney). Check each tool's current terms for commercial use on your plan.
- **Make the mascot first.** Once you have a kitsune you love, use it as the reference image for everything else.
- Log every asset you keep in `docs/ASSET_LOG.md` (tool, date, prompt, plan or licence).
- Purely AI-generated images are not copyrightable in the US. Editing the images yourself (cleanup, recolouring, compositing) strengthens your claim.

## Technical specs

| Asset | Size | Format |
|---|---|---|
| Characters and enemies | 1024×1024, character centred, full body | PNG, transparent background (remove the background after generating) |
| Relic and item icons | 512×512 | PNG, transparent |
| Battle backgrounds | 1080×1920 portrait (9:16); ideally separate far/mid/near layers | PNG/JPG |
| App icon | 1024×1024, no transparency, no text | PNG |

## Reusable style block
Append this to every prompt:

> cute chibi cartoon style, mobile RPG game art, big head small body, soft cel shading with gentle gradients, clean thick dark-brown outlines, glossy highlights, vibrant saturated colours, warm friendly lighting, high detail, polished professional game asset

Negative prompt (if supported):

> realistic, photo, 3d render, horror, gore, dark grim style, blurry, low resolution, text, watermark, logo, signature, extra limbs, deformed hands, cropped

## 1. The kitsune (mascot), make this first

**Character sheet**
> character turnaround sheet of a cute chibi kitsune fox spirit hero, front view, three-quarter view, side view and back view, cream and warm orange fur, white chest and tail tip, big sparkling amber eyes, small pink nose, rosy cheeks, one large fluffy tail with a softly glowing tip, small leather explorer satchel, tiny paper lantern charm on the satchel strap, cheerful brave expression, plain white background, [style block]

**Poses** (use the sheet as the reference image)
> the same chibi kitsune hero, idle stance, gentle smile, slight bounce pose, plain white background, [style block]
> the same chibi kitsune hero, attacking pose, leaping forward with a swipe of glowing magic claws, motion lines, plain white background, [style block]
> the same chibi kitsune hero, hurt pose, eyes squeezed shut, small stars, plain white background, [style block]
> the same chibi kitsune hero, victory pose, arms raised, sparkles, plain white background, [style block]

**Tail progression** (the core mechanic: tails appear as Resonances awaken)
> the same chibi kitsune hero with three fluffy tails, each tail tip glowing a different colour (orange flame, icy cyan, electric yellow), magical aura, plain white background, [style block]
> the same chibi kitsune hero with nine magnificent fluffy tails fanned out behind, glowing tips, majestic but still cute, golden magical aura, plain white background, [style block]

**Expressions** (for UI portraits)
> expression sheet of the same chibi kitsune: happy, determined, surprised, sleepy, proud, sad, head and shoulders only, plain white background, [style block]

## 2. Enemies (biome 1: Lantern Shrine Ruins)

> cute chibi moss slime monster, round green jelly body with moss and tiny flowers on top, small leaf, mischievous eyes, game enemy, plain white background, [style block]

> cute chibi ember imp, small red-orange fire sprite with tiny horns and bat wings, flickering flame tail, cheeky grin, game enemy, plain white background, [style block]

> cute chibi stone sentinel, small chunky guardian made of mossy carved stone blocks, glowing blue eyes, little stone shield, game enemy, plain white background, [style block]

> cute chibi lantern wisp, floating paper lantern spirit with a glowing face and wispy ghost tail, soft golden light, game enemy, plain white background, [style block]

> chibi ruin brute elite enemy, big muscular stone-and-vine creature with a broken pillar club, angry eyebrows, larger than normal enemies, game elite enemy, plain white background, [style block]

> chibi gatekeeper golem boss, huge ancient shrine golem made of carved stone with glowing rune cracks, crystal growing on shoulders, heavy fists, imposing but cute proportions, game boss, plain white background, [style block]

## 3. Relic icons
Shared ending: `, game item icon, centred, rounded composition, soft glow, plain white background, [style block]`

| Relic | Prompt start |
|---|---|
| Ember Stone | a glowing orange gemstone with a small flame dancing inside |
| Frozen Core | a frosty cyan crystal orb with a snowflake inside, icy mist |
| Storm Crystal | a jagged yellow crystal crackling with tiny lightning bolts |
| Chain Relic | an ornate golden chain link charm with a glowing purple gem |
| Whetstone | a small enchanted whetstone with a gleaming silver blade edge |
| Blood Chalice | an ornate crimson chalice with a glowing red liquid |
| Ward Stone | a round blue shield stone with a protective rune, soft barrier glow |
| Hourglass | a small golden hourglass with glowing green sand |

## 4. Backgrounds

> vertical mobile game battle background, ancient lantern shrine ruins in a lush forest, mossy stone steps, red torii-like gate silhouettes in the distance, floating paper lanterns, warm sunset light, soft depth of field, empty ground area in the lower third for characters, no characters, [style block]

> vertical mobile game camp screen background, cozy forest clearing with a small campfire, a tent decorated with lanterns, path leading to glowing shrine ruins in the distance, warm inviting colours, empty centre for the hero, no characters, [style block]

## 5. App icon
> mobile game app icon, close-up of the cute chibi kitsune hero's face smiling, one glowing fluffy tail curling around the frame, bright orange and teal background with sparkles, bold readable at small size, no text, [style block]

## 6. UI
Build the UI in Godot (panels, buttons and rarity frames as clean vector shapes with gradients). That keeps it sharp at every resolution and easy to change. If you want decorative pieces from AI:
> ornate golden fantasy game UI frame border, empty centre, transparent background, [style block]
> fantasy game ribbon banner, red with gold trim, empty centre for text, [style block]

## Workflow
1. Generate 20–40 kitsune sheets. Pick one and refine it until you love it.
2. Train a style model or set it as the reference image.
3. Generate enemies, then icons, then backgrounds, comparing each against the kitsune.
4. Remove backgrounds, crop and resize to the specs above, and save into `assets/` (folder created in M3).
5. Log each asset in `docs/ASSET_LOG.md`.
