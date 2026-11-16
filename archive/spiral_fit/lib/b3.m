function y = b3(x)
%B3  Cardinal cubic B-spline, support [-2, 2], integral 1.
ax = abs(x);
y = zeros(size(x));
m = ax < 1;
y(m) = 2/3 - ax(m).^2 + ax(m).^3 / 2;
m = ax >= 1 & ax < 2;
y(m) = (2 - ax(m)).^3 / 6;
end
