function cam = camera_preset(name, magnification)
%CAMERA_PRESET  Optics and sensor parameters of candidate imaging setups.
%   cam = CAMERA_PRESET(name), name one of
%     'microscope10x'  reflected-light microscope, 10x NA 0.25, mono camera
%     'telecentric2x'  machine-vision camera + 2x telecentric lens
%     'usbMicroscope'  consumer USB digital microscope at high zoom
%     'phoneMacro'     phone main camera + clip-on macro lens
%     'microscope5x'   reflected-light microscope, 5x NA 0.12, with an
%                      eyepiece camera at the image plane (3 um pixels)
%     'keyenceVHX'     Keyence VHX digital microscope, VH-ZST zoom lens,
%                      coaxial light. CAMERA_PRESET('keyenceVHX', mag) sets
%                      the zoom (20-2000x): pixel = 148.8/mag um, from the
%                      lens's 15.24 mm field at 20x over 2048 pixels. Blur and
%                      contrast matched to real images (edge sigma ~1.2-1.7
%                      um at 100-200x, groove/land brightness 0.05-0.10)
%     'phoneEyepiece5x' the same microscope photographed with a phone held
%                      to the eyepiece; blur and glare matched to a real
%                      photo (edge 10-90% ~ 30% of the groove pitch,
%                      groove/land brightness ~ 0.45)
%   All values are typical/assumed, not from a datasheet: replace them
%   with the real numbers of hardware you are considering.
%
%   Fields
%     pixel       pixel size projected onto the record (um)
%     NA          numerical aperture on the record side
%     aberration  extra Gaussian blur from imperfect optics, sigma (um)
%     bits        ADC bit depth
%     fullWell    full-well capacity (electrons)
%     readNoise   read noise (electrons rms)
%     prnu        pixel gain non-uniformity (fraction, rms)
%     nAverage    exposures averaged per position (stop-and-shoot)
%     glare       stray light added everywhere, as a fraction of the
%                 brightness of the flat land
%     wavelength  illumination wavelength (um)
%     sub         supersampling factor per axis used when rendering
%     imageSize   [rows columns] of a full image (keyenceVHX only)

switch name
    case 'microscope10x'
        cam = struct('pixel', 0.345, 'NA', 0.25, 'aberration', 0.1, ...
            'bits', 12, 'fullWell', 10500, 'readNoise', 2.5, 'prnu', 0.01);
    case 'telecentric2x'
        cam = struct('pixel', 1.725, 'NA', 0.07, 'aberration', 0.5, ...
            'bits', 12, 'fullWell', 10500, 'readNoise', 2.5, 'prnu', 0.01);
    case 'usbMicroscope'
        cam = struct('pixel', 2.0, 'NA', 0.06, 'aberration', 2.0, ...
            'bits', 8, 'fullWell', 4000, 'readNoise', 4, 'prnu', 0.02);
    case 'phoneMacro'
        cam = struct('pixel', 1.5, 'NA', 0.08, 'aberration', 1.5, ...
            'bits', 10, 'fullWell', 5000, 'readNoise', 3, 'prnu', 0.01);
    case 'keyenceVHX'
        if nargin < 2
            magnification = 100;
        end
        cam = struct('pixel', 148.8 / magnification, 'NA', 0.1, ...
            'aberration', 0.6, 'bits', 8, 'fullWell', 10000, ...
            'readNoise', 3, 'prnu', 0.01, 'glare', 0.03);
        cam.magnification = magnification;
        cam.imageSize = [1536 2048];     % rows x columns of a still image
    case 'microscope5x'
        cam = struct('pixel', 0.6, 'NA', 0.12, 'aberration', 0.5, ...
            'bits', 8, 'fullWell', 6000, 'readNoise', 3, 'prnu', 0.01, ...
            'glare', 0.05, 'sub', 2);
    case 'phoneEyepiece5x'
        cam = struct('pixel', 2.2, 'NA', 0.12, 'aberration', 9, ...
            'bits', 8, 'fullWell', 6000, 'readNoise', 3, 'prnu', 0.01, ...
            'glare', 0.7, 'sub', 3);
    otherwise
        error('camera_preset:unknown', 'Unknown preset "%s".', name);
end
cam.name = name;
if ~isfield(cam, 'glare')
    cam.glare = 0;
end
cam.nAverage = 1;
cam.wavelength = 0.55;
if ~isfield(cam, 'sub')
    cam.sub = max(2, ceil(cam.pixel / 1.0));   % simulate_scan also
                                               % anti-aliases across the groove
end
end
