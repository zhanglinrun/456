clear; clc; close all;

%% ================= 1. Global config =================
% If you run this file in MATLAB, dataset will be created under ./dataset by default.
% You can change dataset_root to an absolute path if needed.
dataset_root = fullfile(pwd, 'dataset');
num_samples_per_class = 1000;
image_size = [224, 224];

% Save modes
SAVE_RAW_TF = true;          % time-frequency images used for jammer-style classification
SAVE_PC_RANGE_PLOT = false;  % optional: save pulse-compressed range profile images
APPLY_DYNAMIC_ANTI_JAM = true; % compute and log dynamic anti-jam metric (does NOT change RAW TF output)

rng('shuffle');

%% ================= 2. Radar waveform parameters =================
fo  = 0;          % baseband simulation
tau   = 20e-6;      % pulse width
Tr  = 200e-6;     % PRI
ext = 0;
tr  = 50e-6;      % pulse start time inside PRI

% Randomization ranges (recommended)
B_range_hz = [10e6, 80e6];     % chirp bandwidth range
SNR_range_db = [10, 30];       % signal-to-noise ratio range
JSR_range_db = [0, 20];        % total jammer-to-signal ratio range (for nonzero jammer classes)

% Spectrogram parameters (in samples; fixed for stability across B/fs)
win_len = 256;
overlap = 240;
nfft = 512;

jam_names = {
    'J1_Spot', 'J2_Barrage', 'J3_Swept', 'J4_Comb', ...
    'J5_Interrupted', 'J6_DenseTarget', 'J7_NarrowPulse'
};

%% ================= 3. Build tasks =================
tasks = {};
% A) pure signal
tasks{end+1} = {'0_Pure_Signal', []};
% B) single jammer
for ii = 1:7
    tasks{end+1} = {sprintf('Single_%s', jam_names{ii}), ii};
end
% C) 4-jammer composite (C(7,4)=35)
for i = 1:7
    for j = (i+1):7
        for k = (j+1):7
            for l = (k+1):7
                tasks{end+1} = {sprintf('Comp_%s_%s_%s_%s', jam_names{i}, jam_names{j}, jam_names{k}, jam_names{l}), [i j k l]};
            end
        end
    end
end

fprintf('Plan: %d classes, %d samples/class. Total images ~= %d\n', length(tasks), num_samples_per_class, length(tasks)*num_samples_per_class);

if ~exist(dataset_root, 'dir'), mkdir(dataset_root); end

%% ================= 4. Generate =================
for c = 1:length(tasks)
    class_name = tasks{c}{1};
    jam_indices = tasks{c}{2};
    num_jams = numel(jam_indices);

    class_dir = fullfile(dataset_root, class_name);
    if ~exist(class_dir, 'dir'), mkdir(class_dir); end

    % Log file per class
    log_path = fullfile(class_dir, sprintf('%s_log.csv', class_name));
    fid = fopen(log_path, 'w');
    fprintf(fid, 'sample,B_Hz,fs_Hz,SNR_dB,JSR_dB,num_jams,strategy,SINR_base_dB,SINR_best_dB,SINR_improve_dB\n');

    fprintf('[%d/%d] Generating: %s ...\n', c, length(tasks), class_name);

    for i = 1:num_samples_per_class
        %% ---- 4.1 Randomize bandwidth and sampling ----
        B_current = (B_range_hz(1) + (B_range_hz(2)-B_range_hz(1))*rand());
        fs_current = ceil(2.5 * B_current);  % oversample to avoid aliasing

        [sig_curr, t_current, t2t_current, ~, n0_current, N_current, ~, ~, ts_current, ~, chip_current] = ...
            signal(B_current, fs_current, fo, tau, Tr, 0, 0, tr, ext);

        sig_curr = sig_curr(:).';
        t_current = t_current(:).';

        % Average signal power (linear)
        Ps = mean(abs(sig_curr).^2) + eps;

        %% ---- 4.2 Noise by SNR ----
        SNR_dB = SNR_range_db(1) + (SNR_range_db(2)-SNR_range_db(1))*rand();
        Pn = Ps / 10^(SNR_dB/10);
        noise = sqrt(Pn/2) * (randn(1, N_current) + 1i*randn(1, N_current));

        %% ---- 4.3 Generate (unscaled) jammers and scale to target JSR ----
        jam_total = zeros(1, N_current);
        JSR_dB = 0;

        if num_jams > 0
            JSR_dB = JSR_range_db(1) + (JSR_range_db(2)-JSR_range_db(1))*rand();
            Pj_total_target = Ps * 10^(JSR_dB/10);

            % Random power split across jammers (Dirichlet-like)
            w = rand(1, num_jams);
            w = w / sum(w);

            for jj = 1:num_jams
                jam_id = jam_indices(jj);
                jam_raw = zeros(1, N_current);

                switch jam_id
                    case 1 % Spot
                        f_off = (rand()-0.5) * B_current * 0.15;
                        jam_raw = namj(N_current, t_current, f_off, 0, 0, 0.05, 0, Tr, ts_current, Tr);
                    case 2 % Barrage / noise FM
                        jam_raw = nfmj(N_current, t_current, 0, 0, 1e11, Tr, 1, 0, Tr, ts_current);
                    case 3 % Swept
                        if rand > 0.5
                            f_s = -B_current/2; f_e = B_current/2;
                        else
                            f_s = B_current/2; f_e = -B_current/2;
                        end
                        jam_raw = sfj1(N_current, 0, f_s, f_e, Tr, fs_current, t_current);
                    case 4 % Comb
                        jam_raw = csj(N_current, t_current, 0, chip_current, 0, ts_current, 3, tau, tau, B_current);
                    case 5 % Interrupted sampling
                        tmp = isfj(N_current, 0, ts_current, chip_current, 0, n0_current, 4, tau, tau, 0.5, zeros(1,5), t2t_current);
                        jam_raw = pad_or_trim(tmp, N_current);
                    case 6 % Dense false target
                        tmp = dftj(N_current, 0, ts_current, chip_current, tr, 4, tau, tau, 0.5, zeros(1,10), t2t_current);
                        jam_raw = pad_or_trim(tmp, N_current);
                    case 7 % Narrow pulse
                        start_t = rand() * 10e-6;
                        jam_raw = npj(N_current, t_current, 0, 0, 1, 2e-6, 20e-6, 5, start_t);
                end

                % Scale raw jammer to its target power share
                Pj_target = Pj_total_target * w(jj);
                Pj_raw = mean(abs(jam_raw).^2) + eps;
                jam_total = jam_total + jam_raw * sqrt(Pj_target / Pj_raw);
            end
        end

        %% ---- 4.4 Received signal ----
        rx = sig_curr + jam_total + noise;
        rx(~isfinite(rx)) = 0; % only fix bad samples (do NOT zero whole vector)

        %% ---- 4.5 Dynamic anti-jam (for logging only) ----
        strategy = '';
        sinr_base_db = NaN;
        sinr_best_db = NaN;
        sinr_improve_db = NaN;

        if APPLY_DYNAMIC_ANTI_JAM
            try
                [~, strategy, sinr_improve_db, sinr_base_db, sinr_best_db] = dynamic_anti_jamming(rx, chip_current, sig_curr);
            catch
                strategy = 'ERR';
            end
        end

        %% ---- 4.6 Make RAW time-frequency image ----
        if SAVE_RAW_TF
            S_img = make_tf_image(rx, fs_current, win_len, overlap, nfft, image_size);
            fname = sprintf('%s_%04d.png', class_name, i);
            imwrite(S_img, fullfile(class_dir, fname));
        end

        %% ---- 4.7 Write log row ----
        fprintf(fid, '%d,%.6e,%.6e,%.2f,%.2f,%d,%s,%.3f,%.3f,%.3f\n', ...
            i, B_current, fs_current, SNR_dB, JSR_dB, num_jams, strategy, sinr_base_db, sinr_best_db, sinr_improve_db);
    end

    fclose(fid);
end

fprintf('All done! Dataset saved to: %s\n', dataset_root);

%% ================= Helper functions (local) =================
function x = pad_or_trim(x, N)
    x = x(:).';
    if length(x) > N
        x = x(1:N);
    elseif length(x) < N
        x = [x, zeros(1, N-length(x))];
    end
end

function rgb = make_tf_image(x, fs, win_len, overlap, nfft, image_size)
%MAKE_TF_IMAGE  Create frequency-centered, percentile-normalized spectrogram RGB image

    x = x(:).';
    % Ensure win_len not longer than signal
    win_len = min(win_len, max(16, floor(length(x)/2)));
    overlap = min(overlap, win_len-1);

    [S, ~, ~] = spectrogram(x, win_len, overlap, nfft, fs);

    % Complex input => two-sided; center 0 Hz using fftshift along frequency axis
    S = fftshift(S, 1);

    SdB = 20*log10(abs(S) + 1e-12);

    % Robust contrast: clip by percentiles
    lo = prctile(SdB(:), 1);
    hi = prctile(SdB(:), 99);
    SdB = min(max(SdB, lo), hi);
    S01 = (SdB - lo) / (hi - lo + eps);

    S01 = imresize(S01, image_size);

    idx = uint8(round(S01 * 255));
    rgb = ind2rgb(double(idx)+1, jet(256));
end
