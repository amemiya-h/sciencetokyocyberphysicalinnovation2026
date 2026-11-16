# Groove image to music: the story for the presentation

Theme: inverse problems. Each step below is one slide; the figure named
with it is drawn from the real recording by `code/examples/visualize_steps.m`
(saved in `results/figures/`).

## The one-sentence version

We filmed a record under a microscope while turning it by hand, and
recovered 102.6 s of stereo music from nothing but the pictures.

## Framing: why this is an inverse problem

- **Forward process.** Music moves a cutter; the cutter leaves a wavy
  groove; a microscope turns the groove into pictures.
- **Inverse problem.** From the pictures, find the music.
- **What makes it hard.** We do not know how the disc moved between
  pictures; the wiggle is about a micrometre while one reading of an edge
  is uncertain by two thirds of a micrometre; and turning position into
  sound amplifies the noise.
- **How it is solved.** Not by one big fit. The unknowns are peeled off
  one at a time, each using a fact about records that must be true.

| Fact about records | What it lets us find |
|---|---|
| A groove is dark between two bright lands | the edges |
| The same groove carries the same wiggle in every picture | how the disc moved |
| Noise differs between pictures, the groove does not | a cleaner groove |
| The groove is a spiral | where one revolution ends |
| Records are cut at constant turning speed | the time axis |
| A cutter cannot move faster than sound allows | which readings are dust |

## The steps

### 1. Find the edges  (figure `step1_edges`)

In every column of the picture, find where bright turns to dark and back.
Placing the crossing between two pixels gives the edge to a fraction of a
pixel. Left panel: the edges drawn on the picture. Right panel: one
column's brightness with the crossings marked.

Say: "This is the only step that touches the image. Everything after it
works on curves."

### 2. Isolate the wiggle  (figure `step2_wiggle`)

A groove's line in the picture is tilted and curved, because it is part
of a circle and the camera is not perfectly square to it. Remove that
smooth shape and what remains is the wiggle the music made.

Say: "The wiggle is both the signal we want and the fingerprint we use to
line the pictures up."

### 3. Find how the disc moved  (figure `step3_shift`)

Take the same groove in two consecutive pictures. Slide one against the
other and score the match at every trial shift. The best score is how far
the disc turned: 114.8 pixels in the example. All grooves vote together,
so quiet grooves are carried by loud ones.

Say: "The disc was turned by hand. Steps ranged from 66 pixels backward
to 656 forward. The method never needed to be told."

Inverse-problem link: the motion is a nuisance parameter, estimated from
the data's own redundancy.

### 4. Average every view  (figure `step4_views`)

Each point of groove was photographed about five times. Line the views
up, slide each picture sideways to cancel hand shake, and average. The
grey lines are single views; the red line is their average.

Say: "One view is good to 0.66 micrometres. Averaging brings the noise to
about 0.2 micrometres per frequency band."

### 5. Close the revolution  (figure `step5_closure`)

The groove is a spiral. After one full turn, a groove band shows exactly
what its inner neighbour showed at the start. Finding the offset where
that happens gives the length of one revolution, and lets the bands be
laid end to end as one continuous groove: 57 turns.

Say: "One revolution is 1.8 seconds of music. That single fact gives us
the time axis, with no measurement of radius or speed."

Inverse-problem link: a constraint from the physics of the object (it is
a spiral) replaces a measurement we did not have.

### 6. Turn edges into sound  (figure `step6_sound`)

Each edge is one stereo channel. A pickup responds to how fast the groove
moves, not where it is, so the position is differentiated, then passed
through the standard playback curve.

Say: "This is the ill-posed step. Differentiating multiplies every
frequency by itself, so it boosts the treble, which is where our noise is."

### 7. Regularise with measured noise  (figure `step7_filter`)

Build the result twice, from odd pictures and from even pictures. What
they share is groove; what differs is noise. That gives the noise level at
every frequency, measured, not assumed. Each frequency is then kept in
proportion to how much of it is groove.

Say: "A plain low-pass filter is truncated SVD: keep components below a
cutoff. This is Tikhonov: weight each component by signal over signal
plus noise. And the regularisation parameter is measured from the data."

Numbers for the slide (30x): factor 0.99 at 1 kHz, 0.78 at 4 kHz, 0.36 at
6 kHz, 0.06 at 12 kHz.

Why Fourier components are the singular vectors here: every operation
along the groove acts the same at every position.

## Results slide

| | 30x | 50x |
|---|---|---|
| Pixel size | 4.96 um | 2.98 um |
| Music recovered | 102.6 s, 57 turns | about 56 s expected |
| Usable up to about | 3-6 kHz | 10 kHz |
| Signal-to-noise at 1-3 kHz | 13 dB | 21 dB |
| Signal-to-noise at 3-6 kHz | 3 dB | 13 dB |

Play the 30x audio here. It is recognisable and the stereo is correct.

## How we know it is right

- An earlier, completely separate implementation gives the same loudness
  profile (correlation 0.98).
- The noise figures are measured by splitting the data, not modelled.
- It sounds like the record.

## Honest limits (one slide, or for questions)

- One revolution at one radius; a whole side needs many rings joined.
- Treble is limited by magnification and lighting, not by the method.
- The 50x gain mixes three changes (pixel size, more views, more
  contrast) that have not been separated.
- No test record yet, so channel separation and frequency response are
  unmeasured.

## Likely questions

- **Why not one large least-squares fit?** The earlier implementation did
  that, with a pose for every frame. On this same recording its log shows
  24 places where the result jumped by a whole groove. Peeling off one
  unknown at a time, each from a strong constraint, was more robust.
- **Is the problem ill-posed?** The differentiation step is, mildly:
  noise grows in proportion to frequency. The registration step is
  well-posed where there is music and degenerate in silence, which is why
  all grooves vote together.
- **What is the regularisation parameter?** The noise-to-signal ratio at
  each frequency, measured from odd against even frames.
- **Could it go faster than playing the record?** At 30x the filming
  already is (82 s for 102.6 s of music). Higher magnification costs speed
  quadratically; a faster or line-scan camera buys it back.
