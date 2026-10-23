function H = riaa_response(f)
%RIAA_RESPONSE  RIAA playback (de-emphasis) response, 0 dB at 1 kHz.
%   H = RIAA_RESPONSE(f) returns the complex playback response at the
%   frequencies f (Hz; negative frequencies give the complex conjugate).
%   Time constants 3180, 318 and 75 us. The cutting (pre-emphasis)
%   response is 1./H. Playback applies H to the stylus VELOCITY.

h = @(s) (1 + s*318e-6) ./ ((1 + s*3180e-6) .* (1 + s*75e-6));
H = h(2i*pi*f) / abs(h(2i*pi*1000));
end
