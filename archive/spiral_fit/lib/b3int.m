function C = b3int(z)
%B3INT  Integral of the cardinal cubic B-spline from -inf to z (0..1).
C = zeros(size(z));
C(z >= 2) = 1;
m = z > -2 & z <= -1;  C(m) = (2 + z(m)).^4 / 24;
m = z > -1 & z <= 0;   C(m) = lowhalf(z(m));
m = z > 0 & z < 1;     C(m) = 1 - lowhalf(-z(m));
m = z >= 1 & z < 2;    C(m) = 1 - (2 - z(m)).^4 / 24;
end

function c = lowhalf(z)
% integral from -2 to z for z in [-1, 0]
c = 0.5 + 2*z/3 - z.^3/3 - z.^4/8;
end
