function m = error_metrics(e)
%ERROR_METRICS  Summary statistics of an error vector.
%   m = ERROR_METRICS(e) returns a struct with fields RMSE, MAE, Bias,
%   MaxAbs and MedianAbs, in the units of e. NaNs are ignored.

e = e(~isnan(e));
m.RMSE = sqrt(mean(e.^2));
m.MAE = mean(abs(e));
m.Bias = mean(e);
m.MaxAbs = max(abs(e));
m.MedianAbs = median(abs(e));
end
