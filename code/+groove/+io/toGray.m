function gray = toGray(picture)
%TOGRAY  Convert any image to a double grayscale image in [0, 1].

if isinteger(picture)
    scale = double(intmax(class(picture)));
else
    scale = 1;
end
gray = mean(double(picture), 3) / scale;
end
