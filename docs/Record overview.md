Record project overview

Personal 1: Project overview – digitising records from observed reflections

The aim of the project is to investigate whether the information encoded in a vinyl record’s grooves can be recovered by shining light onto its surface and analysing the reflected light in a single image. By developing an image processing and reconstruction method, the project will explore whether the groove geometry can be inferred accurately enough to simulate stylus movement and reconstruct the original audio signal.

General background
Vinyl records store sound as microscopic variations in the groove. In a conventional mono record, lateral movement of the groove represents the audio signal. Stereo records use more complex modulation involving the two groove walls. As a stylus follows the groove the motion is transmitted through to a magnetic cartridge where relative motion between a magnet and coil changes magnetic flux, inducing voltage. Reflected light intensity off of a surface depends of various factors such as surface orientation, illumination direction, reflectance, roughness and camera position. Therefore in theory the differing intensities of reflected light could be used to infer the groove geometry and the original data that it holds (music). Such a technique would be useful for the purpose of recovering information from damaged records, digitising these analogue records, recovering data without risking additional wear from a stylus + turntable. A single exposure approach would mean a faster means of recovering this information without the need for multiple/repeated scans. Additionally, contributing to the understanding of how reflected light can carry information of the surface can have benefit far beyond just records, it is a principle that can be adapted and applied to fields such as surface inspection and optical metrology for example.

Potential levels of success
Basic feasibility: Show that groove features produce measurable, repeatable patterns in a single image.
Quantitative reconstruction: Recover groove position or geometry and compare it with a known reference, measuring error and the smallest distinguishable feature.
Audio demonstration: Use the reconstructed groove path to generate a simulated audio waveform and compare it against a known test signal or conventional playback.


Workstreams
1.	Optics and experimental setup. Lead the literature review on optical record reading and reflection physics. Select the light source, camera, illumination angle and sample geometry. Build and calibrate the experiment. Establish a reliable reference measurement of the test surface. Main deliverable could be a repeatable optical setup and calibrated image data.
2.	Physics and forward model. Model how height, slope, or groove geometry affect reflection, predict what a camera should observe from a known test pattern. Investigate whether different surface profiles produce similar reflections, comparing predictions with captured images. Main deliverable could be a physical model that explains the measured signal
3.	Image processing and inverse reconstruction. Process and calibrate captured images, developing the algorithm to recover surface pattern. Compare reconstruction with the actual case and analyse resolution, noise sensitivity and reconstruction error. Main deliverable could be a working reconstruction pipeline and quantitative results.

Methodology…
