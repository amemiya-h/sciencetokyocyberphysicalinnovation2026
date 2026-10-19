# Project Overview and Deliverables

## TITLE: Digitising records from observed reflections using a one shot approach

## Overview

Vinyl records store their sound as microscopic variations in their grooves. When a vinyl is played using a record player, it uses a stylus to trace the groove point by point to translate it into sound. However, if an experiment were to be conducted where light is shone on these grooves and capture the reflected light intensity, we can obtain an image that depends on factors such as the disc surface position, orientation, and the shape of the grooves. Therefore, in theory, the differing intensities of reflected light could encode the original data that the vinyl holds (music), from which we can read the whole disc in one shot. This technique could be highly useful in the digitization of analog records, particularly reading music without damaging or causing wear from the stylus and turntable.

## Deliverables

The success of the project would be measured in the following two ways:
1. Evidence from imaging showing that the groove features produce measurable, repeatable intensity patterns.
2. An audio demonstration showing that the reconstructed groove path can produce a simulated audio that is comparable to the original.

## Workstreams

Three workstreams will be divided in the 3-person group.

- Experimental setup and data acquisition: Lead the literature review on optical record reading and reflection physics. Select the light source, camera, illumination angle and sample geometry, then build and calibrate the experiment.
  Deliverable: a repeatable optical setup and calibrated image data.
- Forward modelling: Model how surface height, slope and groove geometry affect reflection, and predict what the camera should observe for a known test pattern. Investigate whether different surface profiles can produce similar reflections (i.e. whether the problem is ambiguous), and compare predictions with captured images.
  Deliverable: a physical model that explains the measured signal.
- Inverse reconstruction: Process and calibrate the images, and apply inverse-problem methods to recover the groove path and profile from the measured intensities.
  Deliverable: a reconstruction algorithm that produces a digital groove profile from image data.


## Methodology

We propose testing three different potential methods of mapping record groove surface geometry in one shot, from which the method that produces the most clear and distinguishable pattern will be brought forward and used as the primary method from which a digital reconstrution of the groove pattern will be made. From this model the motion of a stylus along the surface can be simulated, and therefore the original audio can be deciphered using the physical relationship between stylus motion and voltage that record players use in practice. The three proposed methods are as follows:

1.	Direct observation of visible light. Record grooves consist of two edges oriented at 45 degrees to one another. By illuminating each surface with a light source at 45 degrees to the surface of the record, the geometry of the grooves will be distinguishable by comparing the different intensities of reflected light. Observing this with an appropriately placed camera, the grooves can be mapped by inferring the unknown groove properties from the patterns of reflected light.
2.	Laser speckle interference. Shining a laser on to an optically rough surface will produce a random granular interference pattern that forms when coherent laser light scatters off of the surface. Shining such a light on a sample of a record could reveal surface roughness and changes in surface characteristics, potentially including groove related features. 
3.	Structured light imaging. Instead of illuminating the surface uniformly, displaying a known grid or stripe pattern on a screen and capturing how its reflection is distorted by the groove surface can reveal surface slope and geometry as the original pattern acts as a reference from which distortions can be measured. 


