function y = sidelobe_blanking(y_in, main_idx, guard_half_width, threshold_factor)
%SIDELOBE_BLANKING  Sidelobe blanking in pulse-compressed (range) domain
%   y = sidelobe_blanking(y_in, main_idx, guard_half_width, threshold_factor)
%
% Idea:
%   Protect the mainlobe window [main_idx-guard_half_width, main_idx+guard_half_width].
%   For samples outside this window, if |y|^2 exceeds threshold_factor * max_power,
%   blank (set to 0). This is a simplified SLB model.
%
% Reference (concept):
%   SLB is typically implemented using guard channels / thresholds to blank detections
%   that lie in antenna sidelobes. (See e.g. SLB/SLC discussion in literature.)

    if nargin < 2 || isempty(main_idx)
        % fallback: take peak of y_in
        [~, main_idx] = max(abs(y_in));
    end
    if nargin < 3 || isempty(guard_half_width)
        guard_half_width = round(length(y_in) * 0.02); % default 2% of length
    end
    if nargin < 4 || isempty(threshold_factor)
        threshold_factor = 0.2; % 20% of max power
    end

    y_in = y_in(:).';
    N = length(y_in);
    p = abs(y_in).^2;
    p_max = max(p);
    thr = p_max * threshold_factor;

    y = y_in;

    left = max(1, main_idx - guard_half_width);
    right = min(N, main_idx + guard_half_width);

    mask = true(1, N);
    mask(left:right) = false; % false => protected

    blank_idx = find(mask & (p > thr));
    y(blank_idx) = 0;
end
