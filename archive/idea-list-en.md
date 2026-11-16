# Inverse Problem Project Ideas

Ideas 1–12 are the team's ideas, in order of preference. Ideas marked .b (7.b, 9.b) are alternative takes on the team idea above them. Ideas 13–16 are additional ideas. The added ideas take an existing inspection and try to do it from data that is already being collected, or that is much cheaper to collect.

---

## 1. Pipe wall thinning in power plants

**Title:** Predicting minimum wall thickness in plant piping from sparse ultrasonic readings

**Keywords:** flow-accelerated corrosion, pipe wall thinning, power plants, ultrasonic thickness measurement, inspection planning

**Background:** Fast-flowing water thins steel piping near elbows and orifices, which caused the 2004 Mihama pipe rupture. Plants check thickness at grid points during shutdowns, but the thinnest spot can fall between points, and each measurement requires removing insulation.

**Novelty:**
- Combines a flow-based corrosion model with past readings to predict the full thickness map, not just values at measured points
- Recommends where to measure at the next shutdown

**Unknowns:**
- Overall corrosion rate
- Corrosion enhancement for each fitting type
- Location and size of the thinnest zone near each fitting

**Knowns:**
- Thickness readings from past shutdowns
- Piping layout, flow rate and temperature
- Water chemistry and pipe material

---

## 2. Track monitoring from ordinary trains

**Title:** Recovering track geometry from accelerometers on regular service trains

**Keywords:** railway track geometry, onboard monitoring, condition-based maintenance, vehicle dynamics, regional railways

**Background:** Track geometry is normally measured by special inspection cars a few times a year, which small regional lines struggle to afford. Cheap accelerometers on ordinary trains could monitor tracks daily, but the train's suspension blurs the track shape, and suspension behavior changes with passenger load.

**Novelty:**
- Estimates passenger load and suspension properties together with the track shape, instead of assuming a fixed vehicle
- Turns every passenger run into an inspection

**Unknowns:**
- Vertical and lateral track irregularity along the route
- Passenger load
- Suspension stiffness and damping

**Knowns:**
- Accelerations at the car body, bogie or axle box
- Train speed and position
- Vehicle design data and track data (curves, gradients)

---

## 3. Re-entry heat flux monitoring

**Title:** Designing an embedded sensor layout to estimate surface heat flux on a re-entry heat shield

**Keywords:** atmospheric re-entry, thermal protection system, heat shield, inverse heat conduction, surface heat flux estimation, sensor placement

**Background:** As spaceflight becomes commercial, with passengers expected to travel in and out of the atmosphere in the near future, live monitoring of the heat shield is becoming increasingly important for safety. Surface heating during re-entry can be observed with infrared imaging from aircraft or the ground, but the viewpoint is usually fixed, so it can't give accurate live data over the whole surface. Sensors can't be placed on the outer surface because of the extreme heat, but they can be placed inside the heat shield or on its inner surface.

**Novelty:**
- Estimates surface heat flux live from internal temperatures, as an inverse heat conduction problem
- Proposes a framework for designing the monitoring system: the minimum number of sensors and the layout needed for accurate estimates
- Assesses whether this approach is an effective way to monitor the heat shield

**Unknowns:**
- Surface heat flux over time and across the surface
- Optimal number and locations of sensors (design output)

**Knowns:**
- Temperatures at sensor positions
- Heat shield geometry
- Nominal material properties
- Temperatures from a forward model for a set of baseline re-entry scenarios

---

## 4. Tension in short bridge cables

**Title:** Measuring tension in short and stiff bridge cables where the standard vibration formula fails

**Keywords:** bridge inspection, cable tension, arch bridge hangers, cable-stayed bridges, ambient vibration

**Background:** Inspectors measure cable tension by recording its vibration frequencies and applying a simple string formula. For short, stiff cables such as arch bridge hangers, the cable's bending stiffness and how firmly its ends are clamped distort the frequencies, and the formula can be wrong by tens of percent.

**Novelty:**
- Estimates tension, bending stiffness and end clamping together from the same vibration record
- Makes the method work on the cables where it currently fails

**Unknowns:**
- Cable tension
- Bending stiffness
- End clamping stiffness at each anchor

**Knowns:**
- Accelerations at one or a few points on the cable
- Cable geometry and properties
- Damper locations, temperature

---

## 5. Active structural health monitoring

**Title:** Active excitation to separate damage from unknown loading in structural health monitoring

**Keywords:** structural health monitoring, load–damage ambiguity, active sensing, excitation design, strain sensing, inverse identification

**Background:** In structural monitoring, an increased strain reading is ambiguous: the load may have increased, or the material may have degraded (lost stiffness) and is straining more under the same load. Passive measurements alone often can't tell these apart.

**Novelty:**
- Applies a carefully designed excitation to a structure under unknown operating load, to make damage and load distinguishable
- Estimates both the operating load and the crack or delamination properties from the measured response

**Unknowns:**
- Actual operating load
- Properties of the crack or delamination (location, size)

**Knowns:**
- Structure geometry
- Nominal material properties
- Excitation applied
- Strains at sensor positions
- Strains predicted by a forward model for predetermined load and damage conditions

---

## 6. Bridge damage identification from sparse vibration measurements

**Title:** Identifying localized bridge damage from sparse vibration measurements by inverse finite element model updating

**Keywords:** bridge inspection, structural health monitoring, finite element model updating, vibration-based damage identification, modal analysis, sparse sensing

**Background:** Damage such as local stiffness loss changes a bridge's vibration response. A reliable method using only a few sensors could act as a low-cost screening tool, identifying which parts of a bridge need detailed inspection. This would reduce unnecessary inspections and help extend the service life of existing infrastructure.

**Novelty:**
- Builds a finite element model validated against real bridge vibration data from previous studies
- Quantifies how accurately damage location and severity can be recovered
- Shows how reducing the number of sensors affects identification accuracy
- Identifies limits caused by noise, model uncertainty and damage cases that look alike

**Unknowns:**
- Damage location
- Damage severity

**Knowns:**
- Natural frequencies in healthy and damaged states
- Mode shapes at sensor locations in healthy and damaged states
- Sensor locations and count
- Bridge geometry and material properties
- Damage scenarios from the source study
- Added noise levels to simulate measurement error

---

## 7. Non-destructive testing of internal structure in metal parts

**Title:** Reconstructing hidden internal geometry of metal parts from sparse surface strain measurements

**Keywords:** inverse finite element method, inverse problem, structural health monitoring, strain sensing, shape reconstruction, internal geometry, sparse sensing, sensor placement

**Background:** Internal voids and cavities in metal parts affect their strength but can't be seen from the outside. Under load, these internal features change the strain distribution at the surface, which can be measured with a limited number of strain sensors.

**Novelty:**
- Goes beyond detecting an internal defect, to assessing how well hidden internal structure can be identified from sparse surface measurements
- Gives guidance on sensor placement

**Unknowns:**
- Internal geometry
- Void or cavity position, size, shape and orientation
- Internal material distribution (possibly)

**Knowns:**
- Applied load
- External geometry
- Surface sensor positions and measured surface strains
- Nominal material properties
- Boundary conditions

---

## 7.b Molded part internal structure from surface strain

**Title:** In-line screening of molded parts for internal defects from surface strain under a known load

**Keywords:** injection molding, voids, weld lines, digital image correlation, quality inspection, finite element model

**Background:** Injection-molded parts can contain voids, weak weld lines and poorly oriented fiber zones that aren't visible from the outside. X-ray CT can find them but is slow and expensive, so only a few sample parts are inspected. Mass-produced parts all share the same nominal design, so every part can be compared against a known good reference.

**Novelty:**
- Screens every part by loading it and measuring the surface strain field with a camera (digital image correlation)
- Estimates internal defects from differences against the nominal part's strain field
- Feasibility question: which load cases make which internal defects visible at the surface

**Unknowns:**
- Void position and size
- Weld-line position and strength reduction
- Local stiffness of fiber-orientation zones

**Knowns:**
- Surface strain field from digital image correlation
- Applied loads and support conditions
- Nominal part geometry and material properties

---

## 8. Corrosion detection by combining electrochemical and mechanical measurements

**Title:** Mapping internal corrosion in reinforced concrete by combining electrochemical and mechanical surface measurements

**Keywords:** multi-modal sensing, sensor fusion, inverse problem, electrochemical monitoring, strain sensing, structural health monitoring, data assimilation, uncertainty quantification

**Background:** Corrosion of steel reinforcement inside concrete can't be seen from the surface. Electrochemical measurements and mechanical measurements each capture part of the picture, but with only one type of measurement, different corrosion states can produce similar readings.

**Novelty:**
- Tests whether combining independent electrochemical and mechanical signals makes corrosion states identifiable that can't be distinguished with either one alone
- Quantifies how much the combination improves the corrosion map

**Unknowns:**
- Corrosion location, severity and distribution
- Concrete resistivity
- Mechanical damage
- Environmental state (possibly)

**Knowns:**
- Electrical measurements
- Mechanical surface measurements
- Sensor locations and geometry
- Applied excitation
- Approximate concrete and rebar properties

---

## 9. Pipeline coating defects under cathodic protection

**Title:** Estimating coating defect location and size on buried pipelines from routine potential surveys

**Keywords:** cathodic protection, coating defects, buried pipelines, close-interval potential survey, DCVG, boundary element method

**Background:** Buried steel pipelines are protected from corrosion by a coating plus a small protective current (cathodic protection). Operators check them with potential surveys along the route, and read the data by looking for dips and gradient thresholds. This finds defects roughly but can't size them, and changes in soil resistivity or burial depth produce false alarms.

**Novelty:**
- Estimates defect size, not just location, from survey data operators already collect
- Estimates soil resistivity together with the defects, so soil changes aren't mistaken for coating damage
- Shows how survey design (measurement spacing, instant-off readings) affects what can be recovered

**Unknowns:**
- Defect position along the pipe and around its circumference
- Defect size and number of defects
- Soil resistivity
- Resistance of the intact coating

**Knowns:**
- Pipe geometry and cathodic protection system
- Pipe-to-soil potentials along the route
- Lateral potential gradients (DCVG)
- Potentials at test posts
- Spot soil resistivity readings
- Measurement noise characteristics

---

## 9.b Pipeline coating survey from the rectifier

**Title:** Locating coating damage on buried pipelines from the cathodic protection rectifier, without walking the line

**Keywords:** cathodic protection, coating defects, buried pipelines, impedance spectroscopy, transmission line model, remote monitoring

**Background:** Coating surveys require crews to walk the full pipeline route with electrodes, so they are expensive and done only every few years. Every protected pipeline already has a rectifier that drives current into it, and test posts where the pipe can be measured at intervals.

**Novelty:**
- Uses the rectifier as a signal source by modulating its output at several frequencies
- Locates coating damage from measurements only at the rectifier and existing test posts, with no walking survey
- Feasibility question: how finely damage can be localized from these few points, and how that depends on pipeline length and test post spacing

**Unknowns:**
- Coating condition along the pipe, as conductance per segment
- Location and size of major coating defects
- Soil resistivity

**Knowns:**
- Rectifier voltage and current at each modulation frequency
- Potentials at test posts
- Pipe diameter, length and burial depth, anode location

---

## 10. Noise reduction in small drone propellers

**Title:** Comparing noise reduction methods for small drone propellers at equal thrust

**Keywords:** drones, propeller noise, serrated trailing edge, uneven blade spacing, blade element momentum theory, psychoacoustics, low Reynolds number

**Background:** Most studies of propeller noise reduction test one technique in isolation (only serrations, or only uneven blade spacing), often at constant rotational speed and on different test rigs, so the results can't be compared with each other. Testing at constant speed also tends to show which propellers are weaker, not which are actually quieter. Most research is also on large propellers, leaving a gap at the small scale and low Reynolds numbers of small drones.

**Novelty:**
- Compares variants side by side on the same printer, motor, rig and microphone, at constant thrust, to answer which method works best for the same job
- Compares psychoacoustic metrics (tonality, sharpness) with plain dB levels
- Tests whether serrations and uneven spacing still work on small, low Reynolds number propellers
- Inverse problem: calibrates a blade element momentum model and a semi-empirical noise model against thrust stand and microphone data

Variants to compare: 2-, 3- and 4-blade propellers at the same diameter; serrated or sinusoidal trailing edges; uneven blade spacing (e.g. a 4-blade propeller at 80°/100°/80°/100°); swept or raked blade tips.

**Unknowns:**
- Noise reduction of each variant at constant thrust
- Efficiency lost per dB of noise reduction
- Whether psychoacoustic metrics tell a different story from dB levels
- Model parameters calibrated from measurements

**Knowns:**
- Propeller geometry (diameter, blade count, twist, blade angles)
- Target thrust values
- Motor and speed controller
- Microphone position and distance

---

## 11. Internal crack or delamination characterisation

**Title:** Identifying internal delamination in composite structures from sparse surface strain under uncertain conditions

**Keywords:** composite materials, wind turbine blades, delamination, surface strain sensing, identifiability, robustness, uncertainty quantification

**Background:** Internal delaminations in composite structures such as wind turbine blades are hidden from view. Surface strain measurements can reveal them, but material properties, loading (gusts, wind direction) and sensor readings are all uncertain. Different damage cases can also produce similar surface strains: a small crack at 200 mm depth may look like a larger crack at 300 mm depth.

**Novelty:**
- Assesses how robustly and uniquely damage can be located from sparse measurements, under realistic material, load and measurement uncertainty
- Identifies which damage cases can't be told apart from surface strain alone

**Unknowns:**
- Internal damage location (x, y, z), length, width, depth and severity
- Actual material properties
- Loading (gusts, wind direction)
- Sensor errors

**Knowns:**
- Surface strains and sensor positions
- Geometry
- Load history
- Nominal material properties

---

## 12. Smart irrigation system

**Title:** Reconstructing hidden soil moisture from sparse sensors, using irrigation as active excitation

**Keywords:** precision agriculture, smart irrigation, soil moisture estimation, sparse sensing, active sensing, data assimilation

**Background:** Current commercial sensor-based irrigation systems simply monitor moisture at each sensor and irrigate there when needed. Covering a whole field this way would require a very large number of sensors.

**Novelty:**
- Reconstructs the full soil moisture distribution from sparse sensors, using a 1D or 2D soil water model
- Uses irrigation itself as an excitation: varying irrigation patterns and observing the response makes the moisture distribution easier to determine
- Active sensing: directs new measurements to areas of high uncertainty and updates the model
- Uses the reconstructed picture to decide where and how much water to apply, reducing both water use and uncertainty

**Unknowns:**
- Full volumetric soil water content θ(x, y, z, t)

**Knowns:**
- Water output (flow rate, location, duration)
- Moisture at sensor locations
- Soil temperature, air temperature, humidity
- Drainage conditions (if available)

---

## 13. Battery degradation diagnosis from everyday fast-charging data

**Title:** Diagnosing lithium-ion battery degradation from routine charging sessions

**Keywords:** lithium-ion batteries, EV charging, state of health, degradation modes, fleet monitoring, second-life batteries

**Background:** Finding out why a battery has degraded currently needs a dedicated slow test in a lab. Public fast chargers and fleet chargers already log voltage and current for every session, but this data is only used for billing and basic monitoring. Each session covers only part of the charge range, starting wherever the driver happened to plug in.

**Novelty:**
- Treats ordinary charging sessions as diagnostic data, so every charge becomes a health check
- Combines many partial sessions that start at different charge levels to recover what a full slow test would show
- Feasibility question: how many sessions, and what range of starting charge levels, are needed to separate the degradation causes

**Unknowns:**
- Lost cyclable lithium
- Lost active material at each electrode
- Resistance increase

**Knowns:**
- Charger voltage, current and time for each session
- Battery-reported charge level and temperature
- Cell chemistry and fresh-cell electrode voltage curves from literature

---

## 14. Rail thermal stress from passing-train vibration

**Title:** Estimating rail neutral temperature from the vibration of passing trains

**Keywords:** continuous welded rail, rail buckling, neutral temperature, thermal stress, track vibration, beam on elastic foundation

**Background:** Welded rails are installed under tension so that they don't buckle in hot weather. Over time, the temperature at which the rail is stress-free (the neutral temperature) drifts, and rails can buckle in summer. Measuring it in the field requires unclipping and lifting the rail or cutting it, so it is rarely done.

**Novelty:**
- Estimates axial force from rail vibration as trains pass, using trackside accelerometers
- Uses the daily temperature cycle as a known change in axial force, to separate force from changes in track support stiffness
- Feasibility question: whether the frequency shift caused by axial force is large enough to detect against measurement noise and support variation

**Unknowns:**
- Rail neutral temperature (equivalently, axial force)
- Rail pad and ballast stiffness
- Sleeper support condition

**Knowns:**
- Rail accelerations during train passages
- Rail temperature
- Rail cross-section properties and sleeper spacing
- Train speed and passage times

---

## 15. Bolt looseness from a hammer tap recorded on a phone

**Title:** Estimating bolt preload in a steel joint from the sound of a single hammer tap

**Keywords:** bolted joints, bolt loosening, preload, modal analysis, acoustic inspection, smartphone sensing

**Background:** Bolts in steel structures, machinery and railway equipment loosen over time. Inspection is mostly done by checking each bolt with a torque wrench or by hammer tapping and listening, which depends on the inspector's experience. A loose bolt reduces the contact stiffness of the joint, which shifts its vibration frequencies.

**Novelty:**
- Replaces subjective tap-listening with a quantitative estimate from a phone recording
- Estimates the preload of each bolt in the joint, not just "loose or tight"
- Feasibility question: how many bolts can be told apart from one or a few taps, and where to tap

**Unknowns:**
- Contact stiffness at each bolt (related to preload)
- Joint damping
- Support stiffness of the joint

**Knowns:**
- Sound recording of the tap
- Tap location and microphone position
- Joint geometry and material properties

---

## 16. Sewer pipe damage from existing flow monitors

**Title:** Locating partial collapse and leakage in sewer networks from existing water level monitors

**Keywords:** sewer networks, pipe deterioration, road subsidence, open-channel hydraulics, level monitoring, leak localization

**Background:** Aging sewer pipes can partly collapse or leak, which washes soil away and causes road sinkholes such as the 2025 Yashio collapse. Sewers are inspected with CCTV robots, which is slow, so each pipe is inspected only every several years. Many sewer networks already have water level or flow monitors at manholes for rainfall and overflow management.

**Novelty:**
- Reuses existing level monitors for structural inspection, with no new equipment
- Uses daily flow variation and rain events as natural excitation of the network
- Feasibility question: how precisely damage can be located between sensors, and how that depends on sensor spacing

**Unknowns:**
- Location and degree of cross-section reduction
- Pipe roughness for each segment
- Location and rate of infiltration or leakage

**Knowns:**
- Water levels or flows at monitored manholes
- Rainfall
- Network layout, pipe diameters and slopes
