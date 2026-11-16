# Personal 1: Project overview – Digitising records from observed reflections in one shot

The aim of the project is to investigate whether the information encoded in a vinyl record’s grooves can be recovered by shining light onto its surface and analysing the reflected light in a single image. By developing an image processing and reconstruction method, the project will explore whether the groove geometry can be inferred accurately enough to simulate stylus movement and reconstruct the original audio signal.

## General background
Vinyl records store sound as microscopic variations in the groove. In a conventional mono record, lateral movement of the groove represents the audio signal. Stereo records use more complex modulation involving the two groove walls. As a stylus follows the groove the motion is transmitted through to a magnetic cartridge where relative motion between a magnet and coil changes magnetic flux, inducing voltage. Reflected light intensity off of a surface depends of various factors such as surface orientation, illumination direction, reflectance, roughness and camera position. Therefore in theory the differing intensities of reflected light could be used to infer the groove geometry and the original data that it holds (music). Such a technique would be useful for the purpose of recovering information from damaged records, digitising these analogue records, recovering data without risking additional wear from a stylus + turntable. A single exposure approach would mean a faster means of recovering this information without the need for multiple/repeated scans. Additionally, contributing to the understanding of how reflected light can carry information of the surface can have benefit far beyond just records, it is a principle that can be adapted and applied to fields such as surface inspection and optical metrology for example.

## Potential levels of success
Basic feasibility: Show that groove features produce measurable, repeatable patterns in a single image.
Quantitative reconstruction: Recover groove position or geometry and compare it with a known reference, measuring error and the smallest distinguishable feature.
Audio demonstration: Use the reconstructed groove path to generate a simulated audio waveform and compare it against a known test signal or conventional playback.


## Workstreams
1.	Optics and experimental setup. Lead the literature review on optical record reading and reflection physics. Select the light source, camera, illumination angle and sample geometry. Build and calibrate the experiment. Establish a reliable reference measurement of the test surface. Main deliverable could be a repeatable optical setup and calibrated image data.
2.	Physics and forward model. Model how height, slope, or groove geometry affect reflection, predict what a camera should observe from a known test pattern. Investigate whether different surface profiles produce similar reflections, comparing predictions with captured images. Main deliverable could be a physical model that explains the measured signal
3.	Image processing and inverse reconstruction. Process and calibrate captured images, developing the algorithm to recover surface pattern. Compare reconstruction with the actual case and analyse resolution, noise sensitivity and reconstruction error. Main deliverable could be a working reconstruction pipeline and quantitative results.

## Methodology
Comparing methods of mapping record groove surface geometry in one shot. 
1.	Direct observation of visible light. Record grooves consist of two edges oriented at 45 degrees to one another. By illuminating each surface with a light source at an angle to the surface of the record, the geometry of the grooves will be distinguishable by comparing the different intensities of reflected light. Observing this with a microscopic camera, the grooves can be mapped by inferring the unknown groove properties from the patterns of reflected light, and the movement of the stylus can be estimated. From this simulated movement the original sound can be reconstructed using the relationship between stylus velocity and voltage induced by a connected magnet that record players utilise in practice.
2.	Laser speckle interference. Shining a laser on to an optically rough surface will produce a random granular interference pattern that forms when coherent laser light scatters off of the surface. Shining such a light on a sample of a record could reveal surface roughness and changes in surface characteristics, potentially including groove related features. This method will also be applied in attempt to map groove geometry for comparison against the direct observation method.
3.	Structured light imaging. Instead of illuminating the surface uniformly, displaying a known grid or stripe pattern on a screen and capturing how its reflection is distorted by the groove surface can reveal surface sloped and geometry as the original pattern acts as a reference from which distortions can be measured. This third method for mapping the record surface act as another comparison to the direct observation model and speckle interference method, from which the method that produces the clearest surface image can be brought forward in order to reconstruct the encoded sound.














# Personal 2: Project overview – Self adjusting backpack
Backpack straps loosen as you walk and the ideal tightness of the straps varies depending on load and terrain. The aim of this project is to design a small dc motor that can wind the straps around a spool to a target tension and hold without wasting power. Research on load carriage has found that heavy or poorly fitted packs concentrate pressure on the shoulders, shift the body’s centre of mass, and change walking gait, which can contribute to fatigue, back and shoulder pain, and in some cases nerve compression. A well-adjusted pack transfers more weight to the hips and keeps the load close to the body, but straps loosen with movement and as the pack’s contents settle, and the best tightness changes with the load and terrain. Most people adjust their straps once, or not at all, and put up with the discomfort.
Workstreams
1.	Mechanism and Structure - Design and build the physical module that winds, holds and releases the physical straps.
2.	Electronics, sensing and control – make the module tighten to a target tension and hold.
3.	Testing and safety – define what the project must achieve, prove it does and show it is safe.



























# Someone you know 1: Project overview - Grocery store digital twin


The project would develop a simplified digital twin of a grocery store that works backwards from incomplete inventory data to infer what is happening inside the store. A conventional inventory system tracks what should be happening: how many products are delivered, sold, wasted and left on the shelves. But real stores experience discrepancies. Deliveries may be short, products may expire without being recorded, sales data may be inaccurate, and stock counts may contain errors.
Available data: Sales records, Delivery manifests and delivery scans, Periodic physical stock counts, Waste and expiry logs.
Potential research question: Can a digital twin identify the hidden causes of grocery inventory discrepancies, and determine when and what to measure next to distinguish between otherwise indistinguishable causes?
A grocery store digital twin could help retailers reduce food waste, prevent stockouts, and improve inventory accuracy by identifying the underlying causes of discrepancies between recorded and actual stock levels. Rather than simply flagging missing products, the system would infer whether problems arise from delivery errors, unrecorded waste, inaccurate sales data, or stock-counting mistakes, enabling managers to take targeted corrective action. By also identifying which additional measurements would be most useful, the system could reduce the need for frequent manual stock checks, lowering operational costs while improving product availability, supply-chain efficiency, and profitability.
Workstreams
1.	Digital twin and forward model, define stock-flow equations for deliveries, sales, waste, expiry and inventory adjustments. Generate synthetic data with known ground-truth events. Simulate different products, demand patterns and error scenarios. Validate that the simulated store behaves realistically. Main deliverable: a working simulator that generates both true inventory states and imperfect observations.

2.	Inverse problem and diagnosis, develop a method to estimate hidden stock levels and likely error sources. Start with a transparent baseline, such as inventory-balance residuals and rule-based diagnosis. Develop a probabilistic or optimisation-based method to compare competing explanations. Quantify uncertainty and identify cases where the cause cannot be uniquely determined. Main deliverable: a diagnostic algorithm that takes the simulated observations and outputs estimated causes, quantities and confidence. 


3.	Experimental design and adaptive measurements. Establish baseline performance metrics and experimental test cases. Develop the fixed-count and adaptive-measurement strategies. Test how performance changes with missing records, noisy counts and different measurement budgets. Analyse results statistically and quantify the cost of additional measurements. Main deliverable: a reproducible experiment showing when targeted measurements improve diagnosis and when they do not.




















# Society 1: Project overview – Heat flux solver

How should a limited number of embedded temperature sensors be positioned to maximise identifiability of the surface heat flux on a TPS (thermal protection system)?
Live monitoring of the condition of a TPS/heat shield is an ever increasingly important tool in ensuring the safety of space activities in the age of commercialisation in space, with even humans being expected to travel in and out of the atmosphere as passengers in to not too distant future. Monitoring temperatures/heat flux at the external surface of a craft on re-entry can be done using infrared imagery from air or land based detectors, however limitations of this method in producing accurate live data arise considering the fact that their perspective is often fixed so cannot produce an accurate image across the whole surface. Additionally sensors cannot be placed on the outside surface due to the extreme heat encountered, but may be placed within the TPS or on the internal surface. The question is, is using an inverse calculation to estimate the surface heat flux from internal temperature data the most effective method to monitor this, and how should such a monitoring system be designed? 
Knowns: temperature at sensor positions, geometry, theoretical material properties, temperatures produced by a forward model for a set of baseline re-entry scenarios.
Unknown: the actual surface heat flux, optimal sensor locations and amount.












# Society 2: Project overview - Localising leaks in hidden pipe networks

Description
The project would develop a physics-based digital twin of a hidden water-pipe network that uses pressure fluctuations to infer the location of leaks without needing direct access to the pipes. When a pump, valve or flow condition changes, pressure waves travel through the network and reflect at junctions, changes in pipe diameter and leaks. By analysing these transient pressure signals, it may be possible to infer where a leak has occurred and estimate its size. The challenge is that real networks are rarely perfectly characterised. Older metal pipes may connect to modern plastic pipes, material properties and wall thicknesses may be unknown, and wave speeds, friction, demand and operating conditions may vary. These uncertainties can produce pressure signals that resemble those caused by a leak. The project would simulate these conditions and investigate how reliably leaks can be located when the physical properties of the network are only partially known.
Potential research question: How reliably can pressure-transient measurements localise leaks in heterogeneous pipe networks when pipe material properties and operating conditions are uncertain, and can controlled pressure disturbances improve localisation accuracy?
Water utilities lose significant quantities of treated water through leaks in underground distribution networks, many of which are difficult to access and poorly documented. Locating a leak can otherwise require repeated site visits, acoustic surveys, excavation or shutting down parts of the network. A pressure-based digital twin could help utilities narrow the search area before sending repair teams into the field. Its greatest value would be in older, mixed-material networks where pipe layouts and material properties are uncertain. By estimating both the likely leak location and the uncertainty of that estimate, the system could help engineers decide where to investigate next, reduce unnecessary excavation, limit water loss and prioritise repairs. It could also identify situations in which the pressure data are insufficient for a reliable diagnosis, preventing false confidence in the predicted location.
Workstreams
1.	Pipe network and forward model. Build a simplified one-dimensional pipe network model using pressure-wave propagation. Represent junctions, leaks, pumps and valves. Include different pipe materials, wall properties, friction and uncertain wave speeds. Generate synthetic pressure measurements for known leak locations and sizes. Deliverable: a validated forward simulator that predicts pressure signals from a specified network and leak scenario.
2.	Inverse modelling and leak localisation. Implement a baseline method using pressure-wave arrival times and reflections. Develop an inverse solver that fits simulated pressure histories to estimate leak location and size. Account for unknown material properties and uncertain operating conditions. Compare the predicted leak with the known simulated ground truth. Deliverable: an algorithm that estimates leak locations and quantifies the error in those estimates.

3.	Identifiability and experimental design. Design controlled test cases with different leak sizes, positions, material combinations and noise levels. Quantify how uncertainty affects localisation accuracy. Test different sensor locations and numbers of sensors. Investigate whether controlled pump or valve disturbances improve the ability to distinguish competing leak locations. Deliverable: an evidence-based assessment of which measurement configurations and operating conditions make leak localisation reliable.

Methodology…

