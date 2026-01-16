function y = sidelobe_cancellation(y_in, reference_chip, main_idx, guard_half_width, K)
%SIDELOBE_CANCELLATION  Template-based sidelobe cancellation in range domain
%   y = sidelobe_cancellation(y_in, reference_chip, main_idx, guard_half_width, K)
%
% This is a simplified SLC-like post-processing model (single-channel) intended
% for simulation/dataset generation:
%   1) Compute matched filter autocorrelation template r = conv(chip, conj(fliplr(chip)), 'same').
%      This template represents the range response of an ideal point scatterer (mainlobe + sidelobes).
%   2) Find strong peaks in |y_in| outside the protected mainlobe region of the true target.
%   3) For each strong peak, subtract its scaled, shifted template r (mainlobe of that peak kept,
%      but its sidelobes contribute interference to other ranges).
%
% NOTE:
%   Real SLC often relies on auxiliary/guard channels or adaptive beamforming to cancel interference.
%   Here we implement a single-channel surrogate that is useful for controlled experiments.

    if nargin < 3 || isempty(main_idx)
        [~, main_idx] = max(abs(y_in));
    end
    if nargin < 4 || isempty(guard_half_width)
        guard_half_width = round(length(y_in) * 0.02);
    end
    if nargin < 5 || isempty(K)
        K = 3; % cancel top-3 interference peaks
    end

    y_in = y_in(:).';
    N = length(y_in);

    % Autocorrelation template (range response)
    chip = reference_chip(:).';
    thr = max(abs(chip)) * 1e-4;
    idx = find(abs(chip) > thr);
    if ~isempty(idx)
        chip = chip(idx(1):idx(end));
    end
    r = conv(chip, conj(fliplr(chip)), 'same');
    % Normalize template peak to 1
    [~, r0] = max(abs(r));
    r = r / (r(r0) + eps);

    y = y_in;

    % Protect target mainlobe region
    protect = false(1, N);
    L = max(1, main_idx - guard_half_width);
    R = min(N, main_idx + guard_half_width);
    protect(L:R) = true;

    % Find candidate peaks outside protected region
    mag = abs(y_in);
    mag(protect) = 0;

    % Simple peak picking: take top-K sample indices
    [~, sorted_idx] = sort(mag, 'descend');
    peak_idx = sorted_idx(1:min(K, numel(sorted_idx)));
    peak_idx = peak_idx(mag(peak_idx) > 0);

    for ii = 1:numel(peak_idx)
        k = peak_idx(ii);
        a = y_in(k); % complex amplitude at peak

        % Build shifted template centered at k
        % r is centered at r0; shift amount = k - r0
        shift = k - r0;
        r_shift = circshift(r, [0, shift]);

        % Subtract scaled template, but keep a small protected window around k itself
        % to avoid nuking the peak completely (optional)
        local_guard = round(guard_half_width * 0.5);
        kL = max(1, k - local_guard);
        kR = min(N, k + local_guard);

        tmp = a * r_shift;
        tmp(kL:kR) = 0; % do not subtract near the peak mainlobe

        y = y - tmp;
    end
end
